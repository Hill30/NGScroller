angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
	.factory( 'datasource',
		[ '$log', '$timeout', '$rootScope'

			(console, $timeout, $rootScope)->

				get = (index, count, success)->
					$timeout(
						->
							result = []
							if index > 100 || index < -40
								success []
							else
								for i in [index..index + count-1]
									result.push "item #{i}"
								success(result)
						100
					)

				{
					get
				}

		])
angular.bootstrap(document, ["application"])

###
//# sourceURL=src/scripts/persistentScroll.js
###