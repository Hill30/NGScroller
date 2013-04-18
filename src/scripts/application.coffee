angular.module('application', ['scroller'])
.controller( 'MainCtrl',
[ '$scope'
  ($scope) ->
    $scope.name = 'World'
])
.factory( 'datasource',
[ '$log', '$timeout',

  (console, $timeout)->
    get = (index, count, success)->
      $timeout(
        ->
          result = []
          for i in [index..index + count-1]
            result.push 'item ' + i
          success(result)
        100
      )
    {
    get
    }
])

angular.bootstrap document, ['application']