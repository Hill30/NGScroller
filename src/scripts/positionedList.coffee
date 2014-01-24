angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
	.factory( 'datasource',
		[ '$log', '$timeout', '$rootScope', '$location'

			(console, $timeout, $rootScope, $location)->

				offset = parseInt($location.search().offset || '0')

				$rootScope.position = $location.search().position || ''

				data = []

				for letter in 'abcdefghijk'
					for i in [0..9]
						data.push("#{letter}: 0#{i}")

				get = (index, count, success)->
					$timeout(
						->
							actualIndex = index + offset
							result = []
							start = Math.max(1, actualIndex)
							end = Math.min(actualIndex + count-1, data.length)

							if (start > end)
								success []
							else
								for i in [start..end]
									result.push data[i-1]
								success(result)
						100
					)

				$rootScope.$watch ( -> $rootScope.position),
					->
						if $rootScope.position
							$location.search('position', $rootScope.position)

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
//# sourceURL=src/scripts/positionedList.js
###