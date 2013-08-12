angular.module('application', ['ui.scroll', 'ui.scroll.jqlite'])
.factory( 'datasource',
[ '$log', '$timeout', '$rootScope'

	(console, $timeout, $rootScope)->

		scope = $rootScope.$new()

		get = (index, count, success)->
			$timeout(
					->
						result = []
						for i in [index..index + count-1]
							result.push "item r#{current} ##{i}"
						success(result)
					100
				)

		loading = (value) ->
			$rootScope.loading = value

		current = 0
		$rootScope.update = ->
			#current += 1
			#scope.$broadcast 'update.item', 1, "item r0 #0 updated"
			scope.$broadcast 'update.item', (item) ->
				if item[9] == '1'
					item + ' update'

		revision = -> current

		{
			get
			loading
			scope
			revision
		}

])
