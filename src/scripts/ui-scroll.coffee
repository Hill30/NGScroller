###
globals: angular, window

	List of used element methods available in JQuery but not in JQuery Lite
		in other words if you want to remove dependency on JQuery the following methods are to be implemented:

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

	.directive( 'ngScrollCanvas'
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
				require: ['?^ngScrollViewport', '?^ngScrollCanvas']
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
						bufferPadding = -> viewport.height() * Math.max(0.2, +$attr.padding || 0.5) # some extra space to initate preload in advance

						controller = null

						linker temp = $scope.$new(),
							(template) ->
								temp.$destroy()

								viewport = controllers[0] || angular.element(window)
								canvas = controllers[1] || element.parent()

								switch template[0].localName
									when 'li'
										if canvas[0] == viewport[0]
											throw new Error "element cannot be used as both viewport and canvas: #{canvas[0].outerHTML}"
										topPadding = angular.element('<li/>')
										bottomPadding = angular.element('<li/>')
									when 'tr','dl'
										throw new Error "ng-scroll directive does not support <#{template[0].localName}> as a repeating tag: #{template[0].outerHTML}"
									else
										if canvas[0] == viewport[0]
											# if canvas and the viewport are the same create a new div to service as canvas
											contents = canvas.contents()
											canvas = angular.element('<div/>')
											viewport.append canvas
											canvas.append contents
										topPadding = angular.element('<div/>')
										bottomPadding = angular.element('<div/>')

								viewport.css({'overflow-y': 'auto', 'display': 'block'})
								canvas.css({'overflow-y': 'visible', 'display': 'block'})
								element.before topPadding
								element.after bottomPadding

								controller =
									viewport: viewport
									canvas: canvas
									topPadding: (value) ->
										if arguments.length
											topPadding.height(value)
										else
											topPadding.height()
									bottomPadding: (value) ->
										if arguments.length
											bottomPadding.height(value)
										else
											bottomPadding.height()
									append: (element) -> bottomPadding.before element
									prepend: (element) -> topPadding.after element

						viewport = controller.viewport
						canvas = controller.canvas

						first = 1
						next = 1
						buffer = []
						pending = []
						eof = false
						bof = false
						loading = datasource.loading || (value) ->
						isLoading = false

						removeFromBuffer = (start, stop)->
							for i in [start...stop]
								buffer[i].scope.$destroy()
								buffer[i].element.remove()
							buffer.splice start, stop - start

						reload = ->
							first = 1
							next = 1
							removeFromBuffer(0, buffer.length)
							controller.topPadding(0)
							controller.bottomPadding(0)
							pending = []
							eof = false
							bof = false
							adjustBuffer(true)

						shouldLoadBottom = ->
							if buffer.length
								item = buffer[buffer.length-1]
								!eof && item.element.offset().top - canvas.offset().top + item.element.outerHeight(true) <
								viewport.scrollTop() + viewport.height() + bufferPadding()
							else
								!eof

						clipBottom = ->
							# clip the invisible items off the bottom
							bottomHeight = controller.bottomPadding()
							overage = 0

							for item in buffer[..].reverse()
								if viewport.scrollTop() + viewport.height() + bufferPadding() < item.element.offset().top - canvas.offset().top
									bottomHeight += item.element.outerHeight(true)
									overage++
									eof = false
								else
									break

							if overage > 0
								removeFromBuffer(buffer.length - overage, buffer.length)
								next -= overage
								controller.bottomPadding(bottomHeight)
								console.log "clipped off bottom #{overage} bottom padding #{bottomHeight}"

						shouldLoadTop = ->
							!bof &&
							(!buffer.length || buffer[0].element.offset().top - canvas.offset().top > viewport.scrollTop() - bufferPadding())

						clipTop = ->
							# clip the invisible items off the top
							topHeight = controller.topPadding()
							overage = 0
							for item in buffer
								itemHeight = item.element.outerHeight(true)
								if viewport.scrollTop() - bufferPadding() >= item.element.offset().top - canvas.offset().top + itemHeight
									topHeight += itemHeight
									overage++
									bof = false
								else
									break
							if overage > 0
								removeFromBuffer(0, overage)
								controller.topPadding(topHeight)
								first += overage
								console.log "clipped off top #{overage} top padding #{topHeight}"

						enqueueFetch = (direction)->
							if (!isLoading)
								isLoading = true
								loading(true)
							#console.log "Requesting fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							if pending.push(direction) == 1
								fetch()

						adjustBuffer = (reloadRequested)->
							if buffer[0]
								console.log "top {actual=#{buffer[0].element.offset().top - canvas.offset().top} visible from=#{viewport.scrollTop()}}
bottom {visible through #{viewport.scrollTop() + viewport.height()} actual=#{buffer[buffer.length-1].element.offset().top - canvas.offset().top}}"

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
									controller.prepend clone
									buffer.unshift wrapper
								else
									controller.append clone
									buffer.push wrapper
							# this watch fires once per item inserted after the item template has been processed and values inserted
							# which allows to gather the 'real' height of the thing
							itemScope.$watch 'heightAdjustment', ->
								if top
									newHeight = controller.topPadding() - wrapper.element.outerHeight(true)
									if newHeight >= 0
										controller.topPadding(newHeight)
									else
										scrollTop = viewport.scrollTop() + wrapper.element.outerHeight(true)
										if viewport.height() + scrollTop > canvas.height()
											controller.bottomPadding(controller.bottomPadding() + viewport.height() + scrollTop - canvas.height())
										viewport.scrollTop(scrollTop)
								else
									controller.bottomPadding(Math.max(0,controller.bottomPadding() - wrapper.element.outerHeight(true)))

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
										clipTop()
										if result.length == 0
											eof = true
											console.log "appended: requested #{bufferSize} records starting from #{next} recieved: eof"
											finalize()
											return
										for item in result
											lastScope = insert ++next, item, false

										console.log "appended: #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
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
										clipBottom()
										if result.length == 0
											bof = true
											console.log "prepended: requested #{bufferSize} records starting from #{first-bufferSize} recieved: eof"
											finalize()
											return
										for item in result.reverse()
											lastScope = insert first--, item, true
										console.log "prepended #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
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

						eventListener = null

						if datasource.scope
							eventListener = datasource.scope.$new()
							$scope.$on '$destroy', -> eventListener.$destroy()
							eventListener.$on "update.item", (event, locator, newItem)->
								if angular.isFunction locator
									((wrapper)->
										newItem = locator wrapper.scope[itemName]
										if newItem
											wrapper.scope[itemName] = newItem
									) wrapper,i for wrapper,i in buffer
								else
									if 0 <= locator-first-1 < buffer.length
										buffer[locator-first-1].scope[itemName] = newItem
								undefined

		])