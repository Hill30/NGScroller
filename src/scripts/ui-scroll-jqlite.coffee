angular.module('ui.scroll.jqlite', ['ui.scroll'])
.run [
		'$log', '$window'
		(console, window) ->

			unless window.jQuery

				# angular implementation blows up if elem is the window
				css = angular.element.prototype.css
				angular.element.prototype.css = (name, value) ->
					self = this
					elem = self[0]
					css.call(self, name, value) unless !elem || elem.nodeType == 3 || elem.nodeType == 8 || !elem.style

				# copied from angularjs v1.0.5
				isWindow = (obj) ->
					obj && obj.document && obj.location && obj.alert && obj.setInterval;

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
							throw new Error 'invalid DOM structure ' + self

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
					self = this
					# TODO: add padding, border and margins
					self.height.call(self)

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
					self = this
					elem = self[0]
					method = 'scrollTop'
					prop = 'pageYOffset'

					if isWindow elem
						if angular.isDefined value
							elem.scrollTo self.scrollTop.call(self), value
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
					###
					isWin = isWindow elem
					if angular.isDefined value
						if isWin
							elem.scrollTo self.scrollTop.call(self), value
						else
							elem[ method ] = value;
					else
						if isWin
							if (prop of elem)
								elem[ prop ]
							else
								window.document.documentElement[ method ]
						else
							elem[ method ]
          ###
				}, (value, key) ->
					angular.element.prototype[key] = value unless angular.element.prototype[key]

]
