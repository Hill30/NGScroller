angular.module('ui.scroll.jqlite', ['ui.scroll'])
.service('jqLiteExtras', [

		'$log', '$window'
		(console, window) ->

			registerFor : (element) ->

				# angular implementation blows up if elem is the window
				css = angular.element.prototype.css
				element.prototype.css = (name, value) ->
					self = this
					elem = self[0]
					css.call(self, name, value) unless !elem || elem.nodeType == 3 || elem.nodeType == 8 || !elem.style

				# as defined in angularjs v1.0.5
				isWindow = (obj) ->
					obj && obj.document && obj.location && obj.alert && obj.setInterval;

				scrollTo = (self, direction, value) ->
					elem = self[0]
					[method, prop, preserve] = {
					top:  ['scrollTop', 'pageYOffset', 'scrollLeft']
					left: ['scrollLeft', 'pageXOffset', 'scrollTop']
					}[direction]
					if isWindow elem
						if angular.isDefined value
							elem.scrollTo self[preserve].call(self), value
						else
							if (prop of elem)
								elem[ prop ]
							else
								elem.document.documentElement[ method ]
					else
						if angular.isDefined value
							elem[method] = value
						else
							elem[method]

				getStyle = (elem) ->
					if window.getComputedStyle
						window.getComputedStyle(elem, null)
					else
						elem.currentStyle

				#// returns width/height of element, refactored getWH from jQuery
				getWidthHeight = ( elem, measure, isOuter ) ->

					# Start with offset property
					isWidth = measure != 'height'

					[val, dirA, dirB] = {
						width:  [elem.offsetWidth, 'Left', 'Right']
						height: [elem.offsetHeight, 'Top', 'Bottom']
					}[measure]

					computedStyle = getStyle( elem )
					paddingA = parseFloat( computedStyle[ 'padding' + dirA ] ) || 0
					paddingB = parseFloat( computedStyle[ 'padding' + dirB ] ) || 0
					borderA = parseFloat( computedStyle[ 'border' + dirA + 'Width' ] ) || 0
					borderB = parseFloat( computedStyle[ 'border' + dirB + 'Width' ] ) || 0
					computedMarginA = computedStyle[ 'margin' + dirA ]
					computedMarginB = computedStyle[ 'margin' + dirB ]

					#if ( !supportsPercentMargin )
						#computedMarginA = hackPercentMargin( elem, computedStyle, computedMarginA )
						#computedMarginB = hackPercentMargin( elem, computedStyle, computedMarginB )

					marginA = parseFloat( computedMarginA ) || 0;
					marginB = parseFloat( computedMarginB ) || 0;

					if ( val > 0 )
						val += marginA + marginB if isOuter

					else
						#// Fall back to computed then uncomputed css if necessary
						val = computedStyle[ measure ]
						if ( val < 0 || val == null )
							val = elem.style[ measure ] || 0

						#// Normalize "", auto, and prepare for extra
						val = parseFloat( val ) || 0;

						if ( isOuter )
							#// Add padding, border, margin
							val += paddingA + paddingB + marginA + marginB + borderA + borderB;

					return val;


				# define missing methods
				angular.forEach {

				before: (newElem) ->
					self = this
					elem = self[0]
					parent = self.parent()
					children = parent.contents()
					if children[0] == elem
						parent.prepend newElem
					else
						for i in [1..children.length-1]
							if children[i] == elem
								angular.element(children[i-1]).after newElem
								return
						throw new Error 'invalid DOM structure ' + elem.outerHTML

				height: (value) ->
					self = this
					if angular.isDefined value
						if angular.isNumber value
							value = value + 'px'
						css.call(self, 'height', value)

					else
						elem = self[0]
						parseInt(
							if isWindow elem
								elem.document.documentElement.clientHeight;
							else
								if window.getComputedStyle
									window.getComputedStyle(elem).getPropertyValue('height')
									#IE<9 does not support getComputedStyle
								else elem.clientHeight
						)

				outerHeight: (option) ->
					getWidthHeight(this[0], 'height', option)

				offset: (option)->
					self = this
					if arguments.length
						return if option == undefined
							self
						else
							# TODO:
							setOffset

					box = {top:0, left:0}
					elem = self[0]
					doc = elem && elem.ownerDocument
					if !doc
						return

					docElem = doc.documentElement

					# TODO: Make sure it's not a disconnected DOM node

					box = elem.getBoundingClientRect() if elem.getBoundingClientRect?
					win = doc.defaultView || doc.parentWindow
					top: box.top  + ( win.pageYOffset || docElem.scrollTop )  - ( docElem.clientTop  || 0 ),
					left: box.left + ( win.pageXOffset || docElem.scrollLeft ) - ( docElem.clientLeft || 0 )

				scrollTop: (value) ->
					scrollTo this, 'top', value

				scrollLeft: (value) ->
					scrollTo this, 'left', value

				}, (value, key) ->
					element.prototype[key] = value unless element.prototype[key]

])
.run [
		'$log', '$window', 'jqLiteExtras'
		(console, window, jqLiteExtras) ->

			jqLiteExtras.registerFor angular.element unless window.jQuery

	]
