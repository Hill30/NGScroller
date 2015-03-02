angular.module('application', ['ui.scroll', 'ui.scroll.jqlite']).controller('mainController',
	[ '$scope', '$log', '$timeout'
		($scope, console, $timeout)->
			datasource = {}

			datasource.get = (index, count, success)->
				$timeout(
					->
						result = []
						for i in [index..index + count-1]
							item = {}
							item.id = i
							item.content = "item #" + i
							result.push item
						success(result)
					100
				)

			$scope.datasource =  datasource

			# 1st list adapter implementation

			$scope.firstListAdapter = remain: true

			$scope.updateList1 = ->
				$scope.firstListAdapter.update (scope) ->
					scope.item.content += ' *'

			$scope.removeFromList1 = ->
				$scope.firstListAdapter.delete (scope) ->
					scope.item.id % 2 == 0
				return

			idList1 = 1000

			$scope.addToList1 = ->
				$scope.firstListAdapter.insert 2,
					id: idList1
					content: 'a new one #' + idList1
				idList1++
				return

			# 2nd list adapter implementation

			$scope.updateList2 = ->
				$scope.second.list.adapter.update (scope) ->
					scope.item.content += ' *'

			$scope.removeFromList2 = ->
				$scope.second.list.adapter.delete (scope) ->
					scope.item.id % 2 != 0
				return

			idList2 = 2000

			$scope.addToList2 = ->
				$scope.second.list.adapter.insert 4,
					id: idList2
					content: 'a new one #' + idList2
				idList2++
				return

	])

angular.bootstrap(document, ["application"])

###
//# sourceURL=src/scripts/adapter.js
###