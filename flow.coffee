class Flow extends Function
  constructor: (options) ->
    item = -> item.next arguments...
    item.__proto__      = @__proto__
    item.options        = options
    item.nextBlockIdx   = 0
    item.isMulti        = false
    item._multiCount    = 0
    item._multiError    = null
    item._multiResults  = []
    item._multiSn       = 0
    item._afterCount    = 0
    return item

  # TODO: fix runLater for @multi 
  next: (err) ->
    throw 'Flow: next() called while flow is in multi mode' if @isMulti
    return @ if @frozen
    if @timeoutId
      clearTimeout @timeoutId
      delete @timeoutId
    if @running
      @runLater = arguments
      return @
    @running = true
    fn = if @options.error && err?
      @options.error
    else
      @options.blocks[@nextBlockIdx++] || @options.final
    if fn
      if @options.context
        fn = @options.context[fn] unless typeof fn == 'function'
        fn.apply @options.context, Array::slice.call(arguments).concat [@]
      else
        fn.apply @, arguments
    @running = false
    return @ unless @runLater
    args = @runLater
    delete @runLater
    @next args...

  # signals that the next call to thisFlow should repeat this step.
  # It allows you to create serial loops.
  rewind: (n = 1) ->
    @nextBlockIdx = Math.max 0, @nextBlockIdx - n
    @

  skip: (n = 1) ->
    @nextBlockIdx += n
    @

  # Can be used to generate callbacks that must ALL be called before
  # the next step in the flow is executed. Arguments to those callbacks are
  # accumulated, and an array of of those arguments objects is sent
  # as the one argument to the next step in the flow.
  multi: (resultId) ->
    result_sn = @_multiSn++
    @isMulti  = true
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
      @isMulti        = false
      @_multiSn       = 0
      @next error, results

  after: (fn) ->
    blocks = Array::slice.call @options.blocks
    append = if @_afterCount then blocks.slice(-@_afterCount) else []
    @options.blocks = blocks.slice(0, blocks.length - @_afterCount)
      .concat [fn], append
    @_afterCount++
    @

  # Sets a timeout that freezes a flow and calls the provided callback.
  # This timeout is cleared if the next flow step happens first.
  setTimeout: (milliseconds, timeoutCallback) ->
    throw new Error "timeout already set for this flow step" if @timeoutId
    @timeoutId = setTimeout(
      =>
        @frozen = true
        timeoutCallback.call @
      milliseconds
    )
    @

  # Set error handler
  error: (fn) ->
    @options.error = fn
    @

  # flow-js compatibility:
  TIMEOUT:  @::setTimeout
  REWIND:   @::rewind
  MULTI:    @::multi

  # Defines a flow given any number of functions as arguments.
  @define: -> args = arguments; => new @(blocks: args)()

  # Defines a flow and evaluates it immediately.
  # The first flow function won't receive any arguments.
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
