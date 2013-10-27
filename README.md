# Flow-coffee

Original idea: [flow-js](https://github.com/willconant/flow-js).
You can read about the concept there.

This version is rewritten in coffee using prototypes.
It contains some extra features mostly needed for
[costa](https://github.com/printercu/costa).

## No js version
There is no js version. Just `require('coffee-script')` before
`require('flow-coffee')`.

## Extra features

### Custom context
```coffee
obj =
  someMethod: -> # ...

do new flow(
  context: obj
  blocks: [
    # If context is specified last argument is always a flow instance
    (cb) ->
      @ == obj # true
      cb() # It's callback
    (cb) ->
      do (cb_multi = cb.multi()) -> # multi is also available
        setImmediate -> cb_multi()
    (err, results, cb) -> # ...
    'someMethod' # calls method from context
    (err, cb) -> # other callback
  ]
)
```

### downcase
`REWIND`, `MULTI`, `TIMEOUT` are now `rewind`, `multi` & `setTitmeout`.
Old names are left for compatibility.

### `#define()` returns just function
```coffee
f = flow.define( -> )

f.exec()  # removed. no one used i think
f()       # keep it simple
```

### prototype's aftermath
This version works only on engines that support `__proto__` (v8 & rhino do).

Now it does mater what context you call `multi`, `setTimeout` and other methods.
```coffee
flow.exec(
  ->
    multi = @multi
    ... ->
      func multi() # wrong

  ->
    state = @
    ... ->
      func state.multi() # ok
)
```

### Multiple results are stored in the order the `@multi()` is called, not callbacks
```coffee
nt = proccess.nextTick
it 'should preserve results order', (cb) ->
  run = []
  flow.exec(
    ->
      do (cb = @multi()) -> nt -> nt -> run.push 1; cb 1
      # this will be ready first:
      do (cb = @multi()) -> nt ->       run.push 2; cb 2
    (err, results)->
      assert.deepEqual run, [2, 1]
      assert.deepEqual (x[0] for x in results), [1, 2]
      @()
    cb
  )
```

### Function after `@multi` is called with 2 arguments
It's incompatible with original flow, but I've found it very convenient.

First argument is set to the first error passed to any `@multi()`. Second is the original results array.

### Callback on any error
```coffee
flow.exec(
  -> @ null, 'test'
  (arg) ->
    # strips first (error) arguments for usual callbacks
    assert.equal arg, 'test'
    setImmediate => @ 'error'
  -> # this won't run
).error (err) ->
  # this will run
  # resume flow with @()
```

### Take a look at tests for examples & undocumented features
