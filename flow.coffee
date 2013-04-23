class Flow extends Function
  constructor: (thisFlow) ->
    item = -> item.next arguments...
    item.__proto__      = @__proto__
    item.thisFlow       = thisFlow
    item.nextBlockIdx   = 0
    item._multiCount    = 0
    item._multiError    = null
    item._multiResults  = []
    item._multiSn       = 0
    return item

  # TODO: fix runLater for @multi 
  next: (err) ->
    return @ if @frozen
    if @timeoutId
      clearTimeout @timeoutId
      delete @timeoutId
    if @running
      @runLater = arguments
      return @
    @running = true
    if @thisFlow.error && err?
      @thisFlow.error.apply @, arguments
    else
      @thisFlow.blocks[@nextBlockIdx++]?.apply @, arguments
    @running = false
    return @ unless @runLater
    args = @runLater
    delete @runLater
    @next args...

  # _rewind_ signals that the next call to thisFlow should repeat this step. It allows you
  # to create serial loops.
  rewind: (n = 1) ->
    @nextBlockIdx = Math.max 0, @nextBlockIdx - n
    @

  skip: (n = 1) ->
    @nextBlockIdx += n
    @

  # _multi_ can be used to generate callbacks that must ALL be called before the next step
  # in the flow is executed. Arguments to those callbacks are accumulated, and an array of
  # of those arguments objects is sent as the one argument to the next step in the flow.
  # @param {String} resultId An identifier to get the result of a multi call.
  multi: (resultId) ->
    result_sn = @_multiSn++
    @_multiCount++
    (err) =>
      @_multiCount--
      @_multiError = err if err? && !@_multiError?
      @_multiResults[result_sn] = arguments
      @_multiResults[resultId]  = arguments if resultId
      return @ if @_multiCount
      error           = @_multiError
      results         = @_multiResults
      @_multiError    = null
      @_multiResults  = []
      @_multiSn       = 0
      @next error, results

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
    @

  # set error handler
  error: (fn) ->
    @thisFlow.error = fn
    @

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
    ->
      @between? arguments... if @curItem
      return @() if @curItem >= @items.length
      @rewind()
      @job @items[@curItem++]
    ->
      @finish?()
  )

if module?.exports
  module.exports = Flow
else if define?.amd
  define -> Flow
else
  @flow = Flow
