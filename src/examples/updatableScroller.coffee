angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
.factory( 'datasource',
[ '$log', '$timeout', '$rootScope'

	(console, $timeout, $rootScope)->

		scope = $rootScope.$new()

		get = (index, count, success)->
			$timeout(
					->
						result = []

						start = Math.max(1, index)
						end = Math.min(index + count-1, 100)

						if start > end
							success []
						else
							for i in [index..index + count-1]
								result.push "item r#{current} ##{i}"
							success(result)
					1000
				)

		current = 0

		$rootScope.refresh = ->
			current += 1

		$rootScope.delete = ->
			scope.$broadcast 'delete.items', (scope) ->
				scope.item[9] == '1'

		$rootScope.update = ->
			scope.$broadcast 'update.items', (scope) ->
				if scope.item[9] == '1'
					scope.item = scope.item + ' update'

		$rootScope.insert = ->
			scope.$broadcast 'insert.item', 2, "inserted value"

		$rootScope.parseInt = (value) -> parseInt value, 10

		revision = -> current

		{
			get
			scope
			revision
		}

])
angular.bootstrap(document, ["application"])

###
//# sourceURL=src/scripts/updatableScroller.js
###