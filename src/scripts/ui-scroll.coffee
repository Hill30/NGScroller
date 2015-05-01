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
		[ '$log', '$injector', '$rootScope', '$timeout', '$q',
			(console, $injector, $rootScope, $timeout, $q) ->

				$animate = $injector.get('$animate') if $injector.has && $injector.has('$animate')

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

						getValueChain = (targetScope, target) ->
							return if not targetScope
							chain = target.match(/^([\w]+)\.(.+)$/)
							return targetScope[target] if not chain or chain.length isnt 3
							return getValueChain(targetScope[chain[1]], chain[2])

						setValueChain = (targetScope, target, value, doNotSet) ->
							return if not targetScope or not target
							if not chain = target.match(/^([\w]+)\.(.+)$/)
								return if target.indexOf('.') isnt -1
							if not chain or chain.length isnt 3
								return targetScope[target] = value if !angular.isObject(targetScope[target]) and !doNotSet
								return targetScope[target] = value
							targetScope[chain[1]] = {} if !angular.isObject(targetScope[chain[1]]) and !doNotSet
							return setValueChain(targetScope[chain[1]], chain[2], value, doNotSet)

						datasource = getValueChain($scope, datasourceName)
						isDatasourceValid = () -> angular.isObject(datasource) and typeof datasource.get is 'function'

						if !isDatasourceValid() # then try to inject datasource as service
							datasource = $injector.get(datasourceName)
							if !isDatasourceValid()
								throw new Error "#{datasourceName} is not a valid datasource"

						bufferSize = Math.max(3, +$attr.bufferSize || 10)
						bufferPadding = -> viewport.outerHeight() * Math.max(0.1, +$attr.padding || 0.1) # some extra space to initiate preload

						scrollHeight = (elem)->
							elem[0].scrollHeight ? elem[0].document.documentElement.scrollHeight

						# initial settings

						builder = null
						ridActual = 0 # current data revision id
						first = 1
						next = 1
						buffer = []
						pending = []
						eof = false
						bof = false

						# Element manipulation routines

						removeElement =
							if $animate
								(wrapper)->
									$animate.leave wrapper.element,
										->
											wrapper.scope.$destroy()
									buffer.splice buffer.indexOf(wrapper), 1
							else
								(wrapper)->
									wrapper.element.remove()
									wrapper.scope.$destroy()
									buffer.splice buffer.indexOf(wrapper), 1
									deferred = $q.defer()
									deferred.resolve()
									deferred.promise

						appendElement = (wrapper, sibling) ->

						# Element builder
						#
						# Calling linker is the only way I found to get access to the tag name of the template
						# to prevent the directive scope from pollution a new scope is created and destroyed
						# right after the repeaterHandler creation is completed
						linker $scope.$new(), (template) ->

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
									else
										result = angular.element("<#{repeaterType}></#{repeaterType}>")
										result.paddingHeight = result.height
								result

							topPadding = padding(repeaterType)
							element.before topPadding

							bottomPadding = padding(repeaterType)
							element.after bottomPadding

							$scope.$on '$destroy', -> template.remove()

							builder =
								viewport: viewport
								topPadding: -> topPadding.paddingHeight.apply(topPadding, arguments)
								bottomPadding: -> bottomPadding.paddingHeight.apply(bottomPadding, arguments)
								append:  (e) -> element.before.apply(bottomPadding, e)
								prepend: (e) -> element.after.apply(topPadding, e)
								bottomDataPos: ->
									scrollHeight(viewport) - bottomPadding.paddingHeight()
								topDataPos: ->
									topPadding.paddingHeight()

						viewport = builder.viewport

						viewportScope = viewport.scope() || $rootScope

						topVisible = (item) ->
							adapter.topVisible = item.scope[itemName]
							adapter.topVisibleElement = item.element
							adapter.topVisibleScope = item.scope
							setValueChain(viewportScope, $attr.topVisible, adapter.topVisible) if $attr.topVisible
							setValueChain(viewportScope, $attr.topVisibleElement, adapter.topVisibleElement) if $attr.topVisibleElement
							setValueChain(viewportScope, $attr.topVisibleScope, adapter.topVisibleScope) if $attr.topVisibleScope
							datasource.topVisible(item) if typeof datasource.topVisible is 'function'

						loading = (value) ->
							adapter.isLoading = value
							setValueChain($scope, $attr.isLoading, value) if $attr.isLoading
							datasource.loading(value) if typeof datasource.loading is 'function'

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
							adjustBuffer ridActual

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
							if (!adapter.isLoading)
								loading(true)
							if pending.push(direction) == 1
								fetch(rid)

						insert = (item, insertAfter) ->
							itemScope = $scope.$new()
							itemScope[itemName] = item
							wrapper =
								scope: itemScope

							linker itemScope, (clone) ->
								wrapper.element = clone
								# operations: 'append', 'prepend', 'remove', 'update', 'none'
								if (insertAfter)
									wrapper.op = 'append'
									buffer.splice insertAfter+1, 0, wrapper
								else
									wrapper.op = 'prepend'
									buffer.unshift wrapper

						adjustBuffer = (rid, finalize) ->
							for wrapper in buffer.slice(0).reverse() when wrapper.op is 'prepend'
								builder.prepend wrapper.element
								# an element is inserted at the top
								newHeight = builder.topPadding() - wrapper.element.outerHeight(true)
								# adjust padding to prevent it from visually pushing everything down
								if newHeight >= 0
									# if possible, reduce topPadding
									builder.topPadding(newHeight)
								else
									# if not, increment scrollTop
									viewport.scrollTop(viewport.scrollTop() + wrapper.element.outerHeight(true))
								wrapper.op = 'none'

							for wrapper,i in buffer when wrapper.op is 'append'
								#if (i == 0)
									#builder.append wrapper.element
								#else
								buffer[i-1].element.after wrapper.element
								builder.bottomPadding(Math.max(0,builder.bottomPadding() - wrapper.element.outerHeight(true)))
								wrapper.op = 'none'

							for wrapper in buffer.slice(0) when wrapper.op is 'remove'
								removeElement wrapper

							# re-index the buffer
							item.scope.$index = first + i for item,i in buffer

							# We need the item bindings to be processed before we can do adjustment
							$timeout ->
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

						finalize = (rid) ->
							adjustBuffer rid, ->
								pending.shift()
								if pending.length == 0
									loading(false)
								else
									fetch(rid)

						fetch = (rid) ->
							#log "Running fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
							if pending[0] # scrolling down
								if buffer.length && !shouldLoadBottom()
									finalize rid
								else
									#log "appending... requested #{bufferSize} records starting from #{next}"
									datasource.get next, bufferSize,
									(result) ->
										return if (rid and rid isnt ridActual) or $scope.$$destroyed
										if result.length < bufferSize
											eof = true
											builder.bottomPadding(0)
											#log "eof is reached"
										if result.length > 0
											clipTop()
											for item in result
												++next
												insert item, buffer.length
											#log "appended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize rid
							else
								if buffer.length && !shouldLoadTop()
									finalize rid
								else
									#log "prepending... requested #{size} records starting from #{start}"
									datasource.get first-bufferSize, bufferSize,
									(result) ->
										return if (rid and rid isnt ridActual) or $scope.$$destroyed
										if result.length < bufferSize
											bof = true
											builder.topPadding(0)
											#log "bof is reached"
										if result.length > 0
											clipBottom() if buffer.length
											for i in [result.length-1..0]
												--first
												insert result[i]
											#log "prepended: requested #{bufferSize} received #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
										finalize rid

						# events and bindings

						resizeAndScrollHandler = ->
							if !$rootScope.$$phase && !adapter.isLoading
								adjustBuffer()
								$scope.$apply()

						wheelHandler = (event) ->
							scrollTop = viewport[0].scrollTop
							yMax = viewport[0].scrollHeight - viewport[0].clientHeight
							if (scrollTop is 0 and not bof) or (scrollTop is yMax and not eof)
								event.preventDefault()

						viewport.bind 'resize', resizeAndScrollHandler
						viewport.bind 'scroll', resizeAndScrollHandler
						viewport.bind 'mousewheel', wheelHandler

						$scope.$watch datasource.revision, reload

						if datasource.scope
							eventListener = datasource.scope.$new()
						else
							eventListener = $scope.$new()

						$scope.$on '$destroy', ->
							for item in buffer
								item.scope.$destroy()
								item.element.remove()
							viewport.unbind 'resize', resizeAndScrollHandler
							viewport.unbind 'scroll', resizeAndScrollHandler
							viewport.unbind 'mousewheel', wheelHandler


						# adapter initializing

						adapter = {}
						adapter.isLoading = false

						applyUpdate = (bufferClone, index, newItems) ->
							if angular.isArray newItems
								wrapper = bufferClone[index]
								for newItem,i in newItems.reverse()
									if newItem == wrapper.scope[itemName]
										keepIt = true;
									else
										insert newItem, buffer.indexOf wrapper
								unless keepIt
									wrapper.op = 'remove'

						adapter.applyUpdates = (arg1, arg2) ->
							ridActual++
							if angular.isFunction arg1
								# arg1 is the updater function, arg2 is ignored
								bufferClone = buffer.slice(0)
								for wrapper,i in bufferClone  # we need to do it on the buffer clone
									applyUpdate bufferClone, i, arg1(wrapper.scope[itemName], wrapper.scope, wrapper.element)
							else
								# arg1 is item index, arg2 is the newItems array
								if arg1%1 == 0 # checking if it is an integer
									if 0 <= arg1-first < buffer.length
										applyUpdate buffer, arg1 - first, arg2
								else
									throw new Error "applyUpdates - #{arg1} is not a valid index"
							adjustBuffer ridActual

						if $attr.adapter # so we have an adapter on $scope
							adapterOnScope = getValueChain($scope, $attr.adapter)
							if not adapterOnScope
								setValueChain($scope, $attr.adapter, {})
								adapterOnScope = getValueChain($scope, $attr.adapter)
							angular.extend(adapterOnScope, adapter)
							adapter = adapterOnScope

						# update events (deprecated since v1.1.0)

						doUpdate = (locator, newItem) ->
							if angular.isFunction locator
								((wrapper)->
									locator wrapper.scope
								) wrapper for wrapper in buffer
							else
								if 0 <= locator-first-1 < buffer.length
									buffer[locator-first-1].scope[itemName] = newItem
							null

						doDelete = (locator) ->
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

						doInsert = (locator, item) ->
							if angular.isFunction locator
								throw new Error('not implemented - Insert with locator function')
							else
								if 0 <= locator-first-1 < buffer.length
									insert locator, item
									next++
							item.scope.$index = first + i for item,i in buffer
							adjustBuffer()

						eventListener.$on "insert.item", (event, locator, item)->doInsert(locator, item)
						eventListener.$on "update.items", (event, locator, newItem)-> doUpdate(locator, newItem)
						eventListener.$on "delete.items", (event, locator)-> doDelete(locator)

		])

###
//# sourceURL=src/scripts/ui-scroll.js
###
