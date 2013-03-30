# Flow-coffee

Started with few little pull requests for https://github.com/willconant/flow-js. Then got tired of compiling coffee to js, posting it and started this repo.

For now original flow-js is rewritten with using of prototypes. It improved performance & memory usage. Just a little. Benchmarks are inside (you'll need `node-benchmark` package, run it with `nbm bench/flow.coffee`).

## Other differences:

### Helpers
```coffee
flow.anyError = (results) ->
  for result in results
    return result[0] if result?[0]
  null

flow.returnIfAnyError = (results, callback) ->
  return false unless err = @anyError results
  callback? err
  true
```

### Removed upcase
`REWIND`, `MULTI`, `TIMEOUT` are now `rewind`, `multi` & `setTitmeout`. Old names are left for compatibility.

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

### Support for not async functions (not working with `@multi`)
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

### Multiple results are stored in the order the `@multi()` is called, not callbacks.
