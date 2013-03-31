flow = {}

if module?.exports
  module.exports = flow
else if define?.amd
  define -> flow
else
  @flow = flow

flow.FlowState = class FlowState extends Function
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
  next: (args...) ->
    return if @frozen
    if @timeoutId
      clearTimeout @timeoutId
      delete @timeoutId
    return @runLater = args if @running
    @running = true
    @thisFlow.blocks[@nextBlockIdx++]
      ?.apply @, args
    @running = false
    if @runLater
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
flow.define = (args...) ->
  -> new FlowState(blocks: args)()

# defines a flow and evaluates it immediately. The first flow function won't receive any arguments.
flow.exec = (args...) ->
  new FlowState(blocks: args)()

# helper methods
flow.serialForEach = flow.define(
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

flow.anyError = (results) ->
  for result in results
    return result[0] if result?[0]
  null

flow.returnIfAnyError = (results, callback) ->
  return false unless err = @anyError results
  callback? err
  true
