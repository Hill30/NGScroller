angular.module('scroller', [])
  .directive( 'ngScrollCanvas'
    [ '$log'
      (console) ->
        link: (scope, element, attrs, controller) ->
          console.log element
          scope.scrollerCanvas = element

    ])
  .directive( 'ngScroll'
    [ '$log', '$injector'
      (console, $injector) ->
        transclude: 'element'
        priority: 1000
        terminal: true

        compile: (element, attr, linker) ->
          ($scope, $element, $attr) ->

            console.log 'here'
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

                List of used element methods defined in JQuery but not on JQuery Lite
                element.height()
                element.outerHeight(true)
                element.height(value) = only for Top/Bottom padding elements
                element.scrollTop()
                element.scrollTop(value)
                element.position()

                ###

                viewport = angular.element(window)
                canvas = $scope.scrollerCanvas || element.parent()
                console.log element
                console.log element.parent()
                console.log canvas

                topPadding = angular.element('<div/>')
                topPaddingHeight = (value) ->
                  if arguments.length
                    topPadding.height(value)
                  else topPadding.height()
                canvas.prepend(topPadding)

                bottomPadding = angular.element('<div/>')
                bottomPaddingHeight = (value) ->
                  if arguments.length
                    bottomPadding.height(value)
                  else
                    bottomPadding.height()
                canvas.append(bottomPadding)

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
                  topPaddingHeight(0)
                  bottomPaddingHeight(0)
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
                  !eof &&
                  canvas.position().top + canvas.height() - bottomPaddingHeight() < viewport.scrollTop() + viewport.height() + bufferPadding()

                clipBottom = ->
                    # clip off the invisible items form the bottom
                  position = canvas.position().top + topPaddingHeight()
                  bottomHeight = bottomPaddingHeight()
                  overage = 0
                  for item in buffer
                    itemHeight = item.element.outerHeight(true)
                    if position - viewport.scrollTop() >= viewport.height() + bufferPadding()
                      bottomHeight += itemHeight
                      overage++
                      eof = false
                    else
                      position += itemHeight
                  if overage > 0
                    for i in [buffer.length - overage...buffer.length]
                      buffer[i].scope.$destroy()
                      buffer[i].element.remove()
                    buffer.splice buffer.length - overage
                    next -= overage
                    bottomPaddingHeight(bottomHeight)
                    console.log "clipped off bottom #{overage} bottom padding #{bottomHeight}"

                shouldLoadTop = ->
                  first > 1 &&
                  canvas.position().top + topPaddingHeight() > viewport.scrollTop() - bufferPadding()

                clipTop = ->
                  # clip off the invisible items form the top
                  topHeight = topPaddingHeight()
                  overage = 0
                  for item in buffer
                    itemHeight = item.element.outerHeight(true)
                    if viewport.scrollTop() >= canvas.position().top + topHeight + itemHeight + bufferPadding()
                      topHeight += itemHeight
                      overage++
                    else
                      break
                  if overage > 0
                    for i in [0...overage]
                      buffer[i].scope.$destroy()
                      buffer[i].element.remove()
                    buffer.splice 0, overage
                    topPaddingHeight(topHeight)
                    first += overage
                    console.log "clipped off top #{overage} top padding #{topHeight}"

                enqueueFetch = (direction)->
                  loading = true
                  #console.log "Requesting fetch... #{{true:'bottom', false: 'top'}[direction]} pending #{pending.length}"
                  if pending.unshift(direction) == 1
                    fetch()

                adjustBuffer = (reloadRequested)->
                  console.log "top {from=#{canvas.position().top + topPaddingHeight()} visible=#{viewport.scrollTop()}}
    bottom {visible=#{viewport.scrollTop() + viewport.height()} to=#{canvas.position().top + canvas.height() - bottomPaddingHeight()}}"
                  enqueueFetch(true) if reloadRequested || shouldLoadBottom()
                  enqueueFetch(false) if shouldLoadTop()

                append = (item) ->
                  if buffer.length > 0
                    insertAfter = buffer[buffer.length-1].element
                  else
                    insertAfter = topPadding
                  itemScope = $scope.$new()
                  itemScope[itemName] = item
                  wrapper =
                    scope: itemScope
                  linker itemScope,
                    (clone) ->
                      insertAfter.after clone
                      wrapper.element = clone
                      buffer.push wrapper
                  # using watch is the only way I found to gather the 'real' height of the thing - the height after the item
                  # template was processed and values inserted.
                  itemScope.$watch "whatever",
                    ->
                      bottomPaddingHeight(Math.max(0,bottomPaddingHeight() - wrapper.element.outerHeight(true)))

                prepend = (item) ->
                  insertAfter = topPadding
                  itemScope = $scope.$new()
                  itemScope[itemName] = item
                  wrapper =
                    scope: itemScope
                  linker itemScope,
                  (clone) ->
                    insertAfter.after clone
                    wrapper.element = clone
                    buffer.unshift wrapper
                  # using watch is the only way I found to gather the 'real' height of the thing - the height after the item
                  # template was processed and values inserted.
                  itemScope.$watch "whatever",
                  ->
                    topPaddingHeight(Math.max(0,topPaddingHeight() - wrapper.element.outerHeight(true)))

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
                        size -= start + 1
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