angular.module('scroller', [])

  .directive( 'ngScrollViewport'
    [ '$log'
      (console) ->
        controller:
          [ '$scope', '$element'
            (scope, element) -> element
          ]

    ])

  .directive( 'ngScrollCanvas'
    [ '$log'
      (console) ->
        controller:
          [ '$scope', '$element'
            (scope, element) -> element
          ]

    ])

  .directive( 'ngScroll'
    [ '$log', '$injector'
      (console, $injector) ->
        require: ['?^ngScrollViewport', '?^ngScrollCanvas']
        transclude: 'element'
        priority: 1000
        terminal: true

        compile: (element, attr, linker) ->
          ($scope, $element, $attr, controller) ->

            match = $attr.ngScroll.match /^\s*(\w+)\s+in\s+(\w+)\s*$/
            if !match
              throw Error "Expected ngScroll in form of '_item_ in _datasource_' but got '#{$attr.ngScroll}'"

            itemName = match[1]
            datasourceName = match[2]

            $injector.invoke([ datasourceName,
              (datasource) ->

                bufferSize = Math.max(3, $attr.bufferSize || 10)
                bufferPadding = -> viewport.height() * Math.max(.2, $attr.bufferPadding || .5) # some extra space to initate preload in advance

                ###

                List of used element methods available in JQuery but not in JQuery Lite
                in other words if you want to remove dependency on JQuery the following methods are to be implemented:

                element.height()
                element.outerHeight(true)
                element.height(value) = only for Top/Bottom padding elements
                element.scrollTop()
                element.scrollTop(value)
                element.offset()

                ###

                viewport = controller[0] || angular.element(window)
                canvas = controller[1] || element.parent()
                if canvas[0] == viewport[0]
                  # if canvas and the viewport are the same create a new div to service as canvas
                  contents = canvas.contents()
                  canvas = angular.element('<div/>')
                  viewport.append canvas
                  canvas.append contents



                topPadding = angular.element('<div/>')
                element.before topPadding

                bottomPadding = angular.element('<div/>')
                element.after bottomPadding

                first = 1
                next = 1
                buffer = []
                pending = []
                eof = false
                scrollPos = 0
                loading = false

                reload = ->
                  first = 1
                  next = 1
                  buffer.splice 0, buffer.length
                  topPadding.height(0)
                  bottomPadding.height(0)
                  pending = []
                  eof = false
                  scrollPos = 0
                  adjustBuffer(true)

                shouldLoadBottom = ->
                  # we have to keep reading more to the bottom until
                  # we loaded past the item originally selected
                  #globals.doPositioning && globals.selectedText &&
                  #(buffer.length == 0 || scope.defaultText(buffer[buffer.length-1]).toLowerCase() <= globals.selectedText.toLowerCase()) ||
                  # and we have enough for the scrollbar to show up
                  item = buffer[buffer.length-1]
                  if item
                    !eof && item.element.offset().top - canvas.offset().top + item.element.outerHeight(true) <
                      viewport.scrollTop() + viewport.height() + bufferPadding()
                  else
                    true

                clipBottom = ->
                    # clip off the invisible items form the bottom
                  bottomHeight = bottomPadding.height()
                  overage = 0

                  for i in [buffer.length-1..0]
                    itemHeight = buffer[i].element.outerHeight(true)
                    if viewport.scrollTop() + viewport.height() + bufferPadding() < buffer[i].element.offset().top - canvas.offset().top
                      bottomHeight += itemHeight
                      overage++
                      eof = false
                    else
                      break

                  if overage > 0
                    for i in [buffer.length - overage...buffer.length]
                      buffer[i].scope.$destroy()
                      buffer[i].element.remove()
                    buffer.splice buffer.length - overage
                    next -= overage
                    bottomPadding.height(bottomHeight)
                    console.log "clipped off bottom #{overage} bottom padding #{bottomHeight}"

                shouldLoadTop = ->
                  first > 1 &&
                    buffer[0].element.offset().top - canvas.offset().top > viewport.scrollTop() - bufferPadding()

                clipTop = ->
                  # clip off the invisible items form the top
                  topHeight = topPadding.height()
                  overage = 0
                  for item in buffer
                    itemHeight = item.element.outerHeight(true)
                    if viewport.scrollTop() - bufferPadding() >= item.element.offset().top - canvas.offset().top + itemHeight
                      topHeight += itemHeight
                      overage++
                    else
                      break
                  if overage > 0
                    for i in [0...overage]
                      buffer[i].scope.$destroy()
                      buffer[i].element.remove()
                    buffer.splice 0, overage
                    topPadding.height(topHeight)
                    first += overage
                    console.log "clipped off top #{overage} top padding #{topHeight}"

                enqueueFetch = (direction)->
                  loading = true
                  #console.log "Requesting fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
                  if pending.unshift(direction) == 1
                    fetch()

                adjustBuffer = (reloadRequested)->
                  if buffer[0]
                    console.log "top {actual=#{buffer[0].element.offset().top - canvas.offset().top} visible from=#{viewport.scrollTop()}}
    bottom {visible through #{viewport.scrollTop() + viewport.height()} actual=#{buffer[buffer.length-1].element.offset().top - canvas.offset().top}}"

                  enqueueFetch(true) if reloadRequested || shouldLoadBottom()
                  enqueueFetch(false) if shouldLoadTop()

                adjustHeight = (padding, element) ->
                  padding.height(Math.max(0,padding.height() - element.outerHeight(true)))

                append = (item) ->
                  itemScope = $scope.$new()
                  itemScope[itemName] = item
                  wrapper =
                    scope: itemScope
                  linker itemScope,
                    (clone) ->
                      bottomPadding.before clone
                      wrapper.element = clone
                      buffer.push wrapper
                  # using watch is the only way I found to gather the 'real' height of the thing - the height after the item
                  # template was processed and values inserted.
                  itemScope.$watch "whatever",
                    ->
                      bottomPadding.height(Math.max(0,bottomPadding.height() - wrapper.element.outerHeight(true)))

                prepend = (item) ->
                  itemScope = $scope.$new()
                  itemScope[itemName] = item
                  wrapper =
                    scope: itemScope
                  linker itemScope,
                  (clone) ->
                    topPadding.after clone
                    wrapper.element = clone
                    buffer.unshift wrapper
                  # using watch is the only way I found to gather the 'real' height of the thing - the height after the item
                  # template was processed and values inserted.
                  itemScope.$watch "whatever",
                  ->
                    topPadding.height(Math.max(0,topPadding.height() - wrapper.element.outerHeight(true)))

                finalize = ->
                  pending.shift()
                  if pending.length == 0
                    loading = false
                  else
                    fetch()

                fetch = () ->
                  direction = pending[0]
                  #console.log "Running fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
                  if direction
                    if !shouldLoadBottom()
                      finalize()
                    else
                      #console.log "appending... requested #{bufferSize} records starting from #{next}"
                      datasource.get next, bufferSize,
                      (result) ->
                        clipTop()
                        if result.length == 0
                          eof = true
                          console.log "appended: requested #{bufferSize} records starting from #{next} recieved: eof"
                          finalize()
                          return
                        for item in result
                          append item
                        next += result.length
                        console.log "appended: #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
                        finalize()
                        adjustBuffer()

                  else
                    if !shouldLoadTop()
                      finalize()
                    else
                      size = bufferSize
                      start = first - bufferSize
                      if start < 1
                        size += start - 1
                        start  = 1
                      console.log "prepending... requested #{size} records starting from #{start}"
                      datasource.get start, size,
                      (result) ->
                        clipBottom()
                        for item in result.reverse()
                          prepend item
                        first = start
                        console.log "prepended #{result.length} buffer size #{buffer.length} first #{first} next #{next}"
                        finalize()
                        adjustBuffer()

                viewport.bind 'resize', ->
                  adjustBuffer()
                  $scope.$apply()

                viewport.bind 'scroll', ->
                  # if scrolling was requested disable positioning
                  adjustBuffer()
                  $scope.$apply()

                reload()
            ])

    ])