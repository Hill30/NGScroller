###
globals: angular, window

	List of used element methods available in JQuery but not in JQuery Lite

		element.before(elem)
		element.height()
		element.outerHeight(true)
		element.height(value) = only for Top/Bottom padding elements
		element.scrollTop()
		element.scrollTop(value)

###
angular.module('ui.scroll', [])

	.directive( 'uiScrollViewport'
		[ '$log'
			 ->
					controller:
						[ '$scope', '$element'
							(scope, element) ->
								this.viewport = element
								this
						]

		])

	.directive( 'uiScroll'
		[ '$log', '$injector', '$rootScope', '$timeout'
			(console, $injector, $rootScope, $timeout) ->
				require: ['?^uiScrollViewport']
				transclude: 'element'
				priority: 1000
				terminal: true

				compile: (elementTemplate, attr, linker) ->
					($scope, element, $attr, controllers) ->

						log = console.debug || console.log

						match = $attr.uiScroll.match(/^\s*(\w+)\s+in\s+([\w\.]+)\s*$/)
						if !match
							throw new Error "Expected uiScroll in form of '_item_ in _datasource_' but got '#{$attr.uiScroll}'"

						itemName = match[1]
						datasourceName = match[2]

						isDatasource = (datasource) ->
							angular.isObject(datasource) and datasource.get and angular.isFunction(datasource.get)

						getValueChain = (targetScope, target, isSet) ->
							return if not targetScope
							chain = target.match(/^([\w]+)\.(.+)$/)
							if not chain or chain.length isnt 3
								return targetScope[target] = {} if isSet and not angular.isObject(targetScope[target])
								return targetScope[target]
							targetScope[chain[1]] = {} if isSet and not angular.isObject(targetScope[chain[1]])
							return getValueChain(targetScope[chain[1]], chain[2], isSet)

						datasource = getValueChain($scope, datasourceName)

						if !isDatasource datasource
							datasource = $injector.get(datasourceName)
							throw new Error "#{datasourceName} is not a valid datasource" unless isDatasource datasource

						adapterAttr = getValueChain($scope, $attr.adapter, true) if $attr.adapter

						bufferSize = Math.max(3, +$attr.bufferSize || 10)
						bufferPadding = -> viewport.outerHeight() * Math.max(0.1, +$attr.padding || 0.1) # some extra space to initate preload

						scrollHeight = (elem)->
							elem[0].scrollHeight ? elem[0].document.documentElement.scrollHeight

						builder = null
						adapter = {}

						# Calling linker is the only way I found to get access to the tag name of the template
						# to prevent the directive scope from pollution a new scope is created and destroyed
						# right after the repeaterHandler creation is completed
						linker $scope.$new(),
							(template) ->

								repeaterType = template[0].localName
								if repeaterType in ['dl']
									throw new Error "ui-scroll directive does not support <#{template[0].localName}> as a repeating tag: #{template[0].outerHTML}"
								repeaterType = 'div' if repeaterType not in ['li', 'tr']

								viewport = if controllers[0] and controllers[0].viewport then controllers[0].viewport else angular.element(window)
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

								$scope.$on '$destroy', () ->
									template.remove()

								builder =
									viewport: viewport
									topPadding: topPadding.paddingHeight
									bottomPadding: bottomPadding.paddingHeight
									append: bottomPadding.insert
									prepend: topPadding.insert
									bottomDataPos: ->
										scrollHeight(viewport) - bottomPadding.paddingHeight()
									topDataPos: ->
										topPadding.paddingHeight()

						viewport = builder.viewport

						viewportScope = viewport.scope() || $rootScope

						if angular.isDefined($attr.topVisible)
							topVisibleItem = (item)->
								viewportScope[$attr.topVisible] = item

						if angular.isDefined($attr.topVisibleElement)
							topVisibleElement = (element)->
								viewportScope[$attr.topVisibleElement] = element

						if angular.isDefined($attr.topVisibleScope)
							topVisibleScope = (scope)->
								viewportScope[$attr.topVisibleScope] = scope

						topVisible = (item) ->
							topVisibleItem(item.scope[itemName]) if topVisibleItem
							topVisibleElement(item.element) if topVisibleElement
							topVisibleScope(item.scope) if topVisibleScope
							datasource.topVisible(item) if datasource.topVisible

						if angular.isDefined ($attr.isLoading)
							loading = (value) ->
								viewportScope[$attr.isLoading] = value
								datasource.loading(value) if datasource.loading
						else
							loading = (value) ->
								datasource.loading(value) if datasource.loading

						ridActual = 0
						first = 1
						next = 1
						buffer = []
						pending = []
						eof = false
						bof = false
						isLoading = false

						#removes items from start (including) through stop (excluding)
						removeFromBuffer = (start, stop)->
							for i in [start...stop]
								buffer[i].scope.$destroy()
								buffer[i].element.remove()
							buffer.splice start, stop - start

						reload = ->
							ridActual++
							first = 1
							next = 1
							removeFromBuffer(0, buffer.length)
							builder.topPadding(0)
							builder.bottomPadding(0)
							pending = []
							eof = false
							bof = false
							adjustBuffer(ridActual)

						bottomVisiblePos = ->
							viewport.scrollTop() + viewport.outerHeight()

						topVisiblePos = ->
							viewport.scrollTop()

						shouldLoadBottom = ->
							!eof && builder.bottomDataPos() < bottomVisiblePos() + bufferPadding()

						clipBottom = ->
							# clip the invisible items off the bottom
							bottomHeight = 0 #builder.bottomPadding()
							overage = 0

							for i in [buffer.length-1..0]
								item = buffer[i]
								itemTop = item.element.offset().top
								newRow = rowTop isnt itemTop
								rowTop = itemTop
								itemHeight = item.element.outerHeight(true) if newRow
								if (builder.bottomDataPos() - bottomHeight - itemHeight > bottomVisiblePos() + bufferPadding())
									bottomHeight += itemHeight if newRow
									overage++
									eof = false
								else
									break if newRow
									overage++

							if overage > 0
								builder.bottomPadding(builder.bottomPadding() + bottomHeight)
								removeFromBuffer(buffer.length - overage, buffer.length)
								next -= overage
								#log "clipped off bottom #{overage} bottom padding #{builder.bottomPadding()}"

						shouldLoadTop = ->
							!bof && (builder.topDataPos() > topVisiblePos() - bufferPadding())

						clipTop = ->
							# clip the invisible items off the top
							topHeight = 0
							overage = 0
							for item in buffer
								itemTop = item.element.offset().top
								newRow = rowTop isnt itemTop
								rowTop = itemTop
								itemHeight = item.element.outerHeight(true) if newRow
								if (builder.topDataPos() + topHeight + itemHeight < topVisiblePos() - bufferPadding())
									topHeight += itemHeight if newRow
									overage++
									bof = false
								else
									break if newRow
									overage++
							if overage > 0
								builder.topPadding(builder.topPadding() + topHeight)
								removeFromBuffer(0, overage)
								first += overage
								#log "clipped off top #{overage} top padding #{builder.topPadding()}"

						enqueueFetch = (rid, direction)->
							if (!isLoading)
								isLoading = true
								loading(true)
							if pending.push(direction) == 1
								fetch(rid)

						hideElementBeforeAppend = (element) ->
							element.displayTemp = element.css('display')
							element.css 'display', 'none'

						showElementAfterRender = (element) ->
							if element.hasOwnProperty 'displayTemp'
								element.css 'display', element.displayTemp

						insert = (index, item) ->
							itemScope = $scope.$new()
							itemScope[itemName] = item
							toBeAppended = index > first
							itemScope.$index = index
							itemScope.$index-- if toBeAppended
							wrapper =
								scope: itemScope

							linker itemScope,
								(clone) ->
									wrapper.element = clone
									if toBeAppended
										if index == next
											hideElementBeforeAppend clone
											builder.append clone
											buffer.push wrapper
										else
											buffer[index-first].element.after clone
											buffer.splice index-first+1, 0, wrapper
									else
										hideElementBeforeAppend clone
										builder.prepend clone
										buffer.unshift wrapper
							{appended: toBeAppended, wrapper: wrapper}

						adjustRowHeight = (appended, wrapper) ->
							if appended
								builder.bottomPadding(Math.max(0,builder.bottomPadding() - wrapper.element.outerHeight(true)))
							else
								# an element is inserted at the top
								newHeight = builder.topPadding() - wrapper.element.outerHeight(true)
								# adjust padding to prevent it from visually pushing everything down
								if newHeight >= 0
									# if possible, reduce topPadding
									builder.topPadding(newHeight)
								else
									# if not, increment scrollTop
									viewport.scrollTop(viewport.scrollTop() + wrapper.element.outerHeight(true))

						doAdjustment = (rid, finalize)->
							#log "top {actual=#{builder.topDataPos()} visible from=#{topVisiblePos()} bottom {visible through=#{bottomVisiblePos()} actual=#{builder.bottomDataPos()}}"
							if shouldLoadBottom()
								enqueueFetch(rid, true)
							else
								enqueueFetch(rid, false) if shouldLoadTop()
							finalize(rid) if finalize
							if pending.length == 0
								topHeight = 0
								for item in buffer
									itemTop = item.element.offset().top
									newRow = rowTop isnt itemTop
									rowTop = itemTop
									itemHeight = item.element.outerHeight(true) if newRow
									if newRow and (builder.topDataPos() + topHeight + itemHeight < topVisiblePos())
											topHeight += itemHeight
									else
										topVisible(item) if newRow
										break

						adjustBuffer = (rid, newItems, finalize)->
							if newItems and newItems.length
								$timeout ->
									rows = []
									for row in newItems
										elt = row.wrapper.element
										showElementAfterRender elt
										itemTop = elt.offset().top
										if rowTop isnt itemTop
											rows.push(row)
											rowTop = itemTop
									for row in rows
										adjustRowHeight(row.appended, row.wrapper)
									doAdjustment(rid, finalize)
							else
								doAdjustment(rid, finalize)

						finalize = (rid, newItems)->
							adjustBuffer rid, newItems, ->
								pending.shift()
								if pending.length == 0
									isLoading = false
									loading(false)
								else
									fetch(rid)

						fetch = (rid) ->
							direction = pending[0]
							#log "Running fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							if direction
								if buffer.length && !shouldLoadBottom()
									finalize(rid)
								else
									#log "appending... requested #{bufferSize} records starting from #{next}"
									datasource.get next, bufferSize,
									(result) ->
										return if (rid and rid isnt ridActual) or $scope.$$destroyed
										newItems = []
										if result.length < bufferSize
											eof = true
											builder.bottomPadding(0)
											#log "eof is reached"
										if result.length > 0
											clipTop()
											for item in result
												newItems.push (insert ++next, item)
											#log "appended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize(rid, newItems)
							else
								if buffer.length && !shouldLoadTop()
									finalize(rid)
								else
									#log "prepending... requested #{size} records starting from #{start}"
									datasource.get first-bufferSize, bufferSize,
									(result) ->
										return if (rid and rid isnt ridActual) or $scope.$$destroyed
										newItems = []
										if result.length < bufferSize
											bof = true
											builder.topPadding(0)
											#log "bof is reached"
										if result.length > 0
											clipBottom() if buffer.length
											for i in [result.length-1..0]
												newItems.unshift (insert --first, result[i])
											#log "prepended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize(rid, newItems)

						resizeAndResizeHandler = ->
							if !$rootScope.$$phase && !isLoading
								adjustBuffer()
								$scope.$apply()

						viewport.bind 'resize', resizeAndResizeHandler
						viewport.bind 'scroll', resizeAndResizeHandler

						wheelHandler = (event) ->
							scrollTop = viewport[0].scrollTop
							yMax = viewport[0].scrollHeight - viewport[0].clientHeight
							if (scrollTop is 0 and not bof) or (scrollTop is yMax and not eof)
								event.preventDefault()

						viewport.bind 'mousewheel', wheelHandler

						$scope.$watch datasource.revision,
							-> reload()

						if datasource.scope
							eventListener = datasource.scope.$new()
						else
							eventListener = $scope.$new()

						$scope.$on '$destroy', ->
							for item in buffer
								item.scope.$destroy()
								item.element.remove()
							viewport.unbind 'resize', resizeAndResizeHandler
							viewport.unbind 'scroll', resizeAndResizeHandler
							viewport.unbind 'mousewheel', wheelHandler

						adapter.update = (locator, newItem) ->
							if angular.isFunction locator
								((wrapper)->
									locator wrapper.scope
								) wrapper for wrapper in buffer
							else
								if 0 <= locator-first-1 < buffer.length
									buffer[locator-first-1].scope[itemName] = newItem
							null

						adapter.delete = (locator) ->
							if angular.isFunction locator
								temp = []
								temp.unshift item for item in buffer
								((wrapper)->
									if locator wrapper.scope
										removeFromBuffer temp.length-1-i, temp.length-i
										next--
								) wrapper for wrapper,i in temp
							else
								if 0 <= locator-first-1 < buffer.length
									removeFromBuffer locator-first-1, locator-first
									next--

							item.scope.$index = first + i for item,i in buffer
							adjustBuffer()

						adapter.insert = (locator, item) ->
							inserted = []
							if angular.isFunction locator
								throw new Error('not implemented - Insert with locator function')
							else
								if 0 <= locator-first-1 < buffer.length
									inserted.push (insert locator, item)
									next++

							item.scope.$index = first + i for item,i in buffer
							adjustBuffer(null, inserted)

						# deprecated since v1.1.0
						eventListener.$on "insert.item", (event, locator, item)-> adapter.insert(locator, item)
						eventListener.$on "update.items", (event, locator, newItem)-> adapter.update(locator, newItem)
						eventListener.$on "delete.items", (event, locator)-> adapter.delete(locator)

						angular.extend(adapterAttr, adapter) if adapterAttr

		])

###
//# sourceURL=src/scripts/ui-scroll.js
###
