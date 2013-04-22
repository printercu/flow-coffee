_       = require 'underscore'
flow    = require 'flow'
flow_c  = require '../flow'

funcs = []
for i in [1..10]
  do (i = i) =>
    funcs.push ->
      setImmediate =>
        #console.log "#{i}"
        @()

funcs_multi = []
for i in [1..10]
  do (i = i) ->
    funcs_multi.push ->
      for j in [1..10]
        do (cb = @MULTI(), j = j) -> setImmediate ->
          #console.log "#{i}: #{j}"
          cb()
funcs_multi.push -> setImmediate => @()

funcs = funcs_multi

bm_defaults =
  requests:   5000
  concurrent: 50
  type:       'async'

benchmarks = []

conf = simple: funcs, multi: funcs_multi

for name, ary of conf
  benchmarks.push _.extend {}, bm_defaults,
    description:   "flow-js #{name}"
    method:  (cb) ->
      f = ary.slice()
      f.push(cb)
      flow.exec f...

  benchmarks.push _.extend {}, bm_defaults,
    description:  "flow-coffee #{name}"
    method:  (cb) ->
      f = ary.slice()
      f.push(cb)
      flow_c.exec f...

module.exports = (cb) ->
  cb null, benchmarks
