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

		loading = (value) ->
			$rootScope.loading = value

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

		revision = -> current

		{
			get
			loading
			scope
			revision
		}

])
