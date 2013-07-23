angular.module('ui.scroll.jqlite', ['ui.scroll'])
.run [
		'$log', '$window'
		(console, window) ->

			unless window.jQuery

				css = angular.element.prototype.css
				angular.element.prototype.css = (elem, name, value) ->
					css(elem, name, value) unless !elem || elem.nodeType == 3 || elem.nodeType == 8 || !elem.style

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

				}, (value, key) ->
					angular.element.prototype[key] = value unless angular.element.prototype[key]

]
