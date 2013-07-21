angular.module('ui.scroll.jqlite', ['ui.scroll'])
.run [
		'$log', '$window'
		(console, window) ->
			console.log 'config'
			console.log window.jQuery
]
