# Flow-coffee

Started with few little pull requests for https://github.com/willconant/flow-js. Then got tired of compiling coffee to js, posting it and started this repo.

For now original flow-js is rewritten with using of prototypes. It improved performance & memory usage. Just a little. Benchmarks are inside (you'll need `node-benchmark` package, run it with `nbm bench/flow.coffee`).

## Other differences:

### downcase
`REWIND`, `MULTI`, `TIMEOUT` are now `rewind`, `multi` & `setTitmeout`. Old names are left for compatibility.

### `#define()` returns just function
```coffee
f = flow.define( -> )

f.exec()  # removed. no one used i think
f()       # keep it simple
```

### prototype's aftermath
For now works only with engines that support `__proto__` (v8 & rhino do).

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
      func state.func() # ok
)
```

### Support for not async functions (not working with `@multi` yet)
```coffee
flow.exec(
  ->
    console.log 1
    @()
    console.log 2
  ->
    console.log 3
)
# original flow: 1 3 2
# flow-coffee: 1 2 3
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
  -> setImmediate => @ 'error'
  -> # this won't run
).error ->
  # this will run
  # resume flow with @()
```

### Take a look at tests for examples & undocumented features
