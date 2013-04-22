angular.module('application', ['scroller'])
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
