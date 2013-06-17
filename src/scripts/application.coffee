angular.module('application', ['ui.scroll'])
.factory( 'datasource',
[ '$log', '$timeout', '$rootScope'

  (console, $timeout, $rootScope)->
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
      current += 1

    revision = -> current

    {
      get
      loading
      revision
    }

])
