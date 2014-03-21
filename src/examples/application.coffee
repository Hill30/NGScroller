angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
.factory( 'datasource',
[ '$log', '$timeout', '$rootScope'

	(console, $timeout, $rootScope)->

		scope = $rootScope.$new()

		get = (index, count, success)->
			$timeout(
					->
						result = []
						if index > 100000
							success []
						else
							for i in [index..index + count-1]
								result.push "item r#{current} ##{i}"
							success(result)
					100
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
//# sourceURL=src/scripts/application.js
###