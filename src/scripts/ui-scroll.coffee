###
globals: angular, window

	List of used element methods available in JQuery but not in JQuery Lite

		element.before(elem)
		element.height()
		element.offset()
		element.outerHeight(true)
		element.height(value) = only for Top/Bottom padding elements
		element.scrollTop()
		element.scrollTop(value)

###
angular.module('ui.scroll', [])

	.directive( 'ngScrollViewport'
		[ '$log'
			(console) ->
				controller:
					[ '$scope', '$element'
						(scope, element) -> element
					]

		])

	.directive( 'ngScroll'
		[ '$log', '$injector', '$rootScope'
			(console, $injector, $rootScope) ->
				require: ['?^ngScrollViewport']
				transclude: 'element'
				priority: 1000
				terminal: true

				compile: (element, attr, linker) ->
					($scope, $element, $attr, controllers) ->

						match = $attr.ngScroll.match /^\s*(\w+)\s+in\s+(\w+)\s*$/
						if !match
							throw new Error "Expected ngScroll in form of '_item_ in _datasource_' but got '#{$attr.ngScroll}'"

						itemName = match[1]
						datasourceName = match[2]

						isDatasource = (datasource) ->
							angular.isObject(datasource) and datasource.get and angular.isFunction(datasource.get)

						datasource = $scope[datasourceName]
						if !isDatasource datasource
							datasource = $injector.get(datasourceName)
							throw new Error "#{datasourceName} is not a valid datasource" unless isDatasource datasource

						bufferSize = Math.max(3, +$attr.bufferSize || 10)
						bufferPadding = -> viewport.height() * Math.max(0.2, +$attr.padding || 0.5) # some extra space to initate preload

						handler = null

						# Calling linker is the only way I found to get access to the tag name of the template
						# to prevent the directive scope from pollution a new scope is created and destroyed
						# right after the repeaterHandler creation is completed
						linker tempScope = $scope.$new(),
							(template) ->

								repeaterType = template[0].localName
								if repeaterType in ['dl']
									throw new Error "ng-scroll directive does not support <#{template[0].localName}> as a repeating tag: #{template[0].outerHTML}"
								repeaterType = 'div' if repeaterType not in ['li', 'tr']

								viewport = controllers[0] || angular.element(window)
								viewport.css({'overflow-y': 'auto', 'display': 'block'})

								padding = (repeaterType)->
									switch repeaterType
										when 'tr'
											table = angular.element('<table><tr><td><div></div></td></tr></table>')
											div = table.find('div')
											result = table.find('tr')
											result.paddingHeight = -> div.height.apply(div, arguments)
											result
										else
											result = angular.element("<#{repeaterType}></#{repeaterType}>")
											result.paddingHeight = result.height
											result

								createPadding = (padding, element, direction) ->
									element[{top:'before',bottom:'after'}[direction]] padding
									paddingHeight: -> padding.paddingHeight.apply(padding, arguments)
									insert: (element) -> padding[{top:'after',bottom:'before'}[direction]] element

								topPadding = createPadding(padding(repeaterType), element, 'top')
								bottomPadding = createPadding(padding(repeaterType), element, 'bottom')

								scrollHeight = (elem)->
									elem[0].scrollHeight || elem[0].document.documentElement.scrollHeight

								tempScope.$destroy()

								handler =
									viewport: viewport
									topPadding: topPadding.paddingHeight
									bottomPadding: bottomPadding.paddingHeight
									append: bottomPadding.insert
									prepend: topPadding.insert
									bottomDataPos: ->
										scrollHeight(viewport) - bottomPadding.paddingHeight()
									topDataPos: ->
										topPadding.paddingHeight()

						viewport = handler.viewport

						first = 1
						next = 1
						buffer = []
						pending = []
						eof = false
						bof = false
						loading = datasource.loading || (value) ->
						isLoading = false

						#removes items from start trhough stop. start included stop is excluded
						removeFromBuffer = (start, stop)->
							for i in [start...stop]
								buffer[i].scope.$destroy()
								buffer[i].element.remove()
							buffer.splice start, stop - start

						reload = ->
							first = 1
							next = 1
							removeFromBuffer(0, buffer.length)
							handler.topPadding(0)
							handler.bottomPadding(0)
							pending = []
							eof = false
							bof = false
							adjustBuffer(true)

						bottomVisiblePos = ->
							viewport.scrollTop() + viewport.height()

						topVisiblePos = ->
							viewport.scrollTop()

						shouldLoadBottom = ->
							!eof && handler.bottomDataPos() < bottomVisiblePos() + bufferPadding()

						clipBottom = ->
							# clip the invisible items off the bottom
							bottomHeight = 0 #handler.bottomPadding()
							overage = 0

							for item in buffer[..].reverse()
								itemHeight = item.element.outerHeight(true)
								if handler.bottomDataPos() - bottomHeight - itemHeight > bottomVisiblePos() + bufferPadding()
									# top boundary of the element is below the bottom of the visible area
									bottomHeight += itemHeight
									overage++
									eof = false
								else
									break

							if overage > 0
								handler.bottomPadding(handler.bottomPadding() + bottomHeight)
								removeFromBuffer(buffer.length - overage, buffer.length)
								next -= overage
								console.log "clipped off bottom #{overage} bottom padding #{handler.bottomPadding()}"

						shouldLoadTop = ->
							!bof && (handler.topDataPos() > topVisiblePos() - bufferPadding())

						clipTop = ->
							# clip the invisible items off the top
							topHeight = 0
							overage = 0
							for item in buffer
								itemHeight = item.element.outerHeight(true)
								if handler.topDataPos() + topHeight + itemHeight < topVisiblePos() - bufferPadding()
									topHeight += itemHeight
									overage++
									bof = false
								else
									break
							if overage > 0
								handler.topPadding(handler.topPadding() + topHeight)
								removeFromBuffer(0, overage)
								first += overage
								console.log "clipped off top #{overage} top padding #{handler.topPadding()}"

						enqueueFetch = (direction)->
							if (!isLoading)
								isLoading = true
								loading(true)
							#console.log "Requesting fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							if pending.push(direction) == 1
								fetch()

						adjustBuffer = (reloadRequested)->
							console.log "top {actual=#{handler.topDataPos()} visible from=#{topVisiblePos()} bottom {visible through=#{bottomVisiblePos()} actual=#{handler.bottomDataPos()}}"
							#console.log "should be #{(first-1)*29} is #{handler.topPadding()}"

							enqueueFetch(true) if reloadRequested || shouldLoadBottom()
							enqueueFetch(false) if !reloadRequested && shouldLoadTop()

						insert = (index, item, top) ->
							itemScope = $scope.$new()
							itemScope[itemName] = item
							itemScope.$index = index-1
							wrapper =
								scope: itemScope
							linker itemScope,
							(clone) ->
								wrapper.element = clone
								if top
									handler.prepend clone
									buffer.unshift wrapper
								else
									handler.append clone
									buffer.push wrapper

							# this watch fires once per item inserted after the item template has been processed and values inserted
							# which allows to gather the 'real' height of the thing
							itemScope.$watch 'heightAdjustment', ->
								if top
									# an element is inserted at the top
									newHeight = handler.topPadding() - wrapper.element.outerHeight(true)
									# adjust padding to prevent it from visually pushing everything down
									if newHeight >= 0
										# if possible, reduce topPadding
										handler.topPadding(newHeight)
									else
										# if not, increment scrollTop
										scrollTop = viewport.scrollTop() + wrapper.element.outerHeight(true)
										# below is an attempt to ensure that the scrollbar is always there even if
										# there is not enough data. But now I am not sure it is necessary. Commenting out for now
										#if viewport.height() + scrollTop > canvas.height()
										#handler.bottomPadding(handler.bottomPadding() + viewport.height() + scrollTop - canvas.height())
										viewport.scrollTop(scrollTop)
								else
									handler.bottomPadding(Math.max(0,handler.bottomPadding() - wrapper.element.outerHeight(true)))

							itemScope


						finalize = ->
							pending.shift()
							if pending.length == 0
								isLoading = false
								loading(false)
							else
								fetch()

						fetch = () ->
							direction = pending[0]
							#console.log "Running fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							lastScope = null
							if direction
								if buffer.length && !shouldLoadBottom()
									finalize()
								else
									#console.log "appending... requested #{bufferSize} records starting from #{next}"
									datasource.get next, bufferSize,
									(result) ->
										if result.length == 0
											eof = true
											console.log "appended: requested #{bufferSize} records starting from #{next} recieved: eof"
											finalize()
											return
										clipTop()
										for item in result
											lastScope = insert ++next, item, false

										console.log "appended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize()
										lastScope.$watch 'adjustBuffer', ->
											adjustBuffer()

							else
								if buffer.length && !shouldLoadTop()
									finalize()
								else
									#console.log "prepending... requested #{size} records starting from #{start}"
									datasource.get first-bufferSize, bufferSize,
									(result) ->
										if result.length == 0
											bof = true
											console.log "prepended: requested #{bufferSize} records starting from #{first-bufferSize} recieved: bof"
											finalize()
											return
										clipBottom()
										for item in result.reverse()
											lastScope = insert first--, item, true
										console.log "prepended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize()
										lastScope.$watch 'adjustBuffer', ->
											adjustBuffer()

						viewport.bind 'resize', ->
							if !$rootScope.$$phase && !isLoading
								adjustBuffer()
								$scope.$apply()

						viewport.bind 'scroll', ->
							if !$rootScope.$$phase && !isLoading
								adjustBuffer()
								$scope.$apply()

						$scope.$watch datasource.revision,
							-> reload()

						if datasource.scope
							eventListener = datasource.scope.$new()
						else
							eventListener = $scope.$new()
						$scope.$on '$destroy', -> eventListener.$destroy()

						eventListener.$on "update.items", (event, locator, newItem)->
							if angular.isFunction locator
								((wrapper)->
									locator wrapper.scope
								) wrapper for wrapper in buffer
							else
								if 0 <= locator-first-1 < buffer.length
									buffer[locator-first-1].scope[itemName] = newItem
							undefined

						eventListener.$on "delete.items", (event, locator)->
							temp = []
							temp.unshift item for item in buffer
							if angular.isFunction locator
								((wrapper)->
									if locator wrapper.scope
										removeFromBuffer temp.length-1-i, temp.length-i
								) wrapper for wrapper,i in temp
							else
								if 0 <= locator-first-1 < buffer.length
									removeFromBuffer locator-first-1, locator-first

							item.scope.$index = first + i for item,i in buffer

							undefined

		])