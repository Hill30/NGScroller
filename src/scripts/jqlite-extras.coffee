angular.module('ui.scroll.jqlite', ['ui.scroll'])
.run [
		'$log', '$window'
		(console, window) ->
			console.log 'config'
			unless window.jQuery
				console.log angular.element.prototype.html
				console.log angular.element.prototype.height
				css = angular.element.prototype.css
				angular.element.prototype.css = (elem, name, value) ->
					css(elem, name, value) unless !elem || elem.nodeType == 3 || elem.nodeType == 8 || !elem.style

]
