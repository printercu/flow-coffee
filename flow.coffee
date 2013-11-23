class Flow extends Function
  constructor: (options) ->
    self = -> self.next arguments...
    self.__proto__      = @__proto__
    self.options        = options
    self.nextBlockIdx   = 0
    self.isMulti        = false
    self._multiRunning  = 0
    self._multiError    = null
    self._multiResults  = []
    self._multiSn       = 0
    self._afterCount    = 0
    return self

  next: (err) ->
    if @isMulti
      throw new Error 'Flow: next() called while flow is in multi mode'
    return @ if @frozen
    if @timeoutId
      clearTimeout @timeoutId
      delete @timeoutId
    fn = if @options.error && err?
      @options.error
    else
      @options.blocks[@nextBlockIdx++] || @options.final
    @invoke fn, arguments if fn
    @

  invoke: (fn, args = [], callback) ->
    if Array.isArray fn
      @expectMulti()
      for f in fn
        do (callback = @multi()) => @invoke f, args, callback
      return @
    callback ||= @
    err = args[0]
    if @options.context
      fn = @options.context[fn] unless typeof fn == 'function'
      args = Array::slice.call(args, (if @options.error && !err? then 1 else 0))
      args.push callback
      fn.apply @options.context, args
    else
      args = Array::slice.call(args, 1) if @options.error && !err?
      fn.apply callback, args
    @

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
    @_multiRunning++
    (err) =>
      @_multiRunning--
      @_multiError = err if err? && !@_multiError?
      @_multiResults[result_sn] = arguments
      @_multiResults[resultId]  = arguments if resultId
      return @ if @_multiRunning || @_expectMulti
      @_nextMulti()

  _nextMulti: ->
    error           = @_multiError
    results         = @_multiResults
    @_multiError    = null
    @_multiResults  = []
    @isMulti        = false
    @_multiSn       = 0
    @next error, results

  # Use it when you want to run `multi()` but you don't realy know if there
  # will be any call.
  #
  #   flow.exec(
  #     -> fs.readDir dir, @
  #     (err, files) ->
  #       @expectMulti()
  #       for file in files
  #         continue if someComplexCondition(file)
  #         do (cb = @multi()) -> processItem file, cb
  #     (err, results) ->
  #       # ...
  #   )
  #
  # Next step will run on other event loop cycle. So you can use it
  # to prevent sync functions to call next step on current event cycle
  # (but you'd better use `setImmediate` to make callbacks async).
  # Like this:
  #
  #   flow.exec(
  #     ->
  #       @expectMulti()
  #       do (cb = @multi()) -> cb()
  #       # next step would already run if you skip @expectMulti()
  #       do (cb = @multi()) -> cb()
  #     ...
  #   )
  #
  # stopOnEmpty: stop the flow if no `multi()` was called. By default next step
  # will be called with empty array of results.
  expectMulti: (stopOnEmpty) ->
    @_expectMulti = @isMulti = true
    setImmediate =>
      @_expectMulti = false
      return if @_multiRunning || (stopOnEmpty && !@_multiSn)
      @_nextMulti()
    @

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
    throw new Error 'Timeout already set for this flow step' if @timeoutId
    @timeoutId = setTimeout(
      =>
        @frozen = true
        timeoutCallback.call @
      milliseconds
    )
    @

  # Set handlers
  error: (fn) ->
    @options.error = fn
    @

  final: (fn) ->
    @options.final = fn
    @

  # flow-js compatibility:
  TIMEOUT:  @::setTimeout
  REWIND:   @::rewind
  MULTI:    @::multi

  # Defines a flow given any number of functions as arguments.
  @define: ->
    args = arguments
    => new @(blocks: args)()

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
