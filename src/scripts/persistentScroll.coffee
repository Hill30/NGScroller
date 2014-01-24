angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
	.factory( 'datasource',
		[ '$log', '$timeout', '$rootScope', '$location'

			(console, $timeout, $rootScope, $location)->

				offset = parseInt($location.search().offset || '0')

				get = (index, count, success)->
					$timeout(
						->
							actualIndex = index + offset
							result = []
							if actualIndex > 100 || actualIndex < -40
								success []
							else
								for i in [actualIndex..actualIndex + count-1]
									result.push "item #{i}"
								success(result)
						100
					)

				$rootScope.$watch (-> $rootScope.topVisible),
					->
						if $rootScope.topVisible
							$location.search('offset', $rootScope.topVisible.$index + offset)
							$location.replace()
				{
					get
				}

		])
angular.bootstrap(document, ["application"])

###
//# sourceURL=src/scripts/persistentScroll.js
###