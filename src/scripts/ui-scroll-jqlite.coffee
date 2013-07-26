angular.module('ui.scroll.jqlite', ['ui.scroll'])
.run [
		'$log', '$window'
		(console, window) ->

			unless window.jQuery

				css = angular.element.prototype.css
				angular.element.prototype.css = (name, value) ->
					self = this
					elem = self[0]
					css.call(self, name, value) unless !elem || elem.nodeType == 3 || elem.nodeType == 8 || !elem.style

				isWindow = (obj) ->
					obj && obj.document && obj.location && obj.alert && obj.setInterval;

				angular.forEach {

					before: (elem) ->
						self = this
						parent = self.parent()
						children = parent.contents()
						if children[0] == self
							parent.prepend elem
						else
							for i in [0..children.length-1]
								if children[i] == self[0]
									angular.element(children[i-1]).after elem
									return
							throw new Error 'invalid DOM structure ' + self

					height: (value) ->
						self = this
						if angular.isDefined value
							#TODO: support string, function as the value
							css.call(self, 'height', value + 'px')
						else
							elem = self[0]

							if isWindow elem
								elem.document.documentElement.clientHeight;
							else
								parseInt(
									if window.getComputedStyle
										window.getComputedStyle(self[0]).getPropertyValue('height')
									# TODO: the code below ony works if the height is set in pixels
									else self[0].currentStyle.height # for IE8
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
								win.document.documentElement[ method ]
						else
							elem[ method ]

				}, (value, key) ->
					angular.element.prototype[key] = value unless angular.element.prototype[key]

]
