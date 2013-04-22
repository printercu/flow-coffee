class Flow extends Function
  constructor: (thisFlow) ->
    item = (args...) -> item.next args...
    item.__proto__    = @__proto__
    item.thisFlow     = thisFlow
    item.nextBlockIdx = 0
    item.multiCount   = 0
    item.multiOutputs = []
    item.multiOutputsSerial = 0
    return item

  # TODO: fix runLater for @multi 
  next: ->
    return if @frozen
    args = arguments
    if @timeoutId
      clearTimeout @timeoutId
      delete @timeoutId
    return @runLater = args if @running
    @running = true
    @thisFlow.blocks[@nextBlockIdx++]?.apply @, args
    @running = false
    return unless @runLater
    args = @runLater
    delete @runLater
    @next args... 

  # _rewind_ signals that the next call to thisFlow should repeat this step. It allows you
  # to create serial loops.
  rewind: (n = 1) ->
    @nextBlockIdx = Math.max 0, @nextBlockIdx - n

  skip: (n = 1) ->
    @nextBlockIdx += n

  # _multi_ can be used to generate callbacks that must ALL be called before the next step
  # in the flow is executed. Arguments to those callbacks are accumulated, and an array of
  # of those arguments objects is sent as the one argument to the next step in the flow.
  # @param {String} resultId An identifier to get the result of a multi call.
  multi: (resultId) ->
    result_serial = @multiOutputsSerial++
    @multiCount++
    =>
      @multiCount--
      @multiOutputs[result_serial]  = arguments
      @multiOutputs[resultId]       = arguments if resultId
      return if @multiCount
      multiOutputs        = @multiOutputs
      @multiOutputs       = []
      @multiOutputsSerial = 0
      @next multiOutputs

  # _setTimeout_ sets a timeout that freezes a flow and calls the provided callback. This
  # timeout is cleared if the next flow step happens first.
  setTimeout: (milliseconds, timeoutCallback) ->
    throw new Error "timeout already set for this flow step" if @timeoutId
    @timeoutId = setTimeout(
      =>
        @frozen = true
        timeoutCallback.call @
      milliseconds
    )

  # flow-js compatibility:
  TIMEOUT:  @::setTimeout
  REWIND:   @::rewind
  MULTI:    @::multi

  # defines a flow given any number of functions as arguments
  @define: -> args = arguments; => new @(blocks: args)()

  # defines a flow and evaluates it immediately. The first flow function won't receive any arguments.
  @exec: -> new @(blocks: arguments)()

  # helper methods
  @serialForEach: @define(
    (@items, @job, @between, @finish) ->
      @curItem = 0
      @()
    (args...) ->
      @between? args... if @curItem
      return @() if @curItem >= @items.length
      @rewind()
      @job @items[@curItem++]
    ->
      @finish?()
  )

  @anyError: (results) ->
    for result in results
      return result[0] if result?[0]
    null

  @returnIfAnyError: (results, callback) ->
    return false unless err = @anyError results
    callback? err
    true

if module?.exports
  module.exports = Flow
else if define?.amd
  define -> Flow
else
  @flow = Flow