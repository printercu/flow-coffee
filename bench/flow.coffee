_       = require 'underscore'
flow    = require 'flow'
flow_c  = require '../flow'
async   = require 'async'

funcs = []
funcs_async = []
for i in [1..10]
  do (i = i) =>
    funcs.push ->
      setImmediate =>
        @()
    funcs_async.push (cb) ->
      setImmediate =>
        cb null

funcs_multi = []
for i in [1..10]
  do (i = i) ->
    funcs_multi.push ->
      for j in [1..10]
        do (cb = @MULTI(), j = j) -> setImmediate ->
          cb()
funcs_multi.push -> setImmediate => @()

funcs = funcs_multi

bm_defaults =
  requests:   5000
  concurrent: 50
  type:       'async'

benchmarks = []

conf = simple: funcs, multi: funcs_multi

# for name, ary of conf
#   benchmarks.push _.extend {}, bm_defaults,
#     description:   "flow-js #{name}"
#     method:  (cb) ->
#       f = ary.slice()
#       f.push cb
#       flow.exec f...

#   benchmarks.push _.extend {}, bm_defaults,
#     description:  "flow-coffee #{name}"
#     method:  (cb) ->
#       f = ary.slice()
#       f.push cb
#       flow_c.exec f...

# do (ary = funcs_async) ->
#   benchmarks.push _.extend {}, bm_defaults,
#     description:  "async"
#     method:  (cb) ->
#       f = ary.slice()
#       f.push -> cb null
#       async.waterfall f

for name, ary of conf
  benchmarks.push _.extend {}, bm_defaults,
    description:   "flow-js #{name}"
    method:  (cb) ->
      #f = ary.slice()
      #f.push(cb)
      #flow.exec f...
      x = 0
      flow.exec(
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> cb(if x == 10 then null else 'error')
      )

  benchmarks.push _.extend {}, bm_defaults,
    description:  "flow-coffee #{name}"
    method:  (cb) ->
      #f = ary.slice()
      #f.push(cb)
      #flow_c.exec f...
      x = 0
      flow_c.exec(
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> setImmediate => @(x += 1)
        -> cb(if x == 10 then null else 'error')
      )

benchmarks.push _.extend {}, bm_defaults,
  description:  "async"
  method:  (cb) ->
    # f = funcs_async.slice()
    # f.push(cb)
    # async.waterfall f
    x = 0
    async.waterfall [
      (cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      (a, cb) -> setImmediate => cb(null, x += 1)
      -> cb(if x == 10 then null else 'error')
    ]

benchmarks.push _.extend {}, bm_defaults,
  description:  "pure"
  method:  (cb) ->
    x = 0
    do => setImmediate =>
      x += 1; setImmediate =>
        x += 1; setImmediate =>
          x += 1; setImmediate =>
            x += 1; setImmediate =>
              x += 1; setImmediate =>
                x += 1; setImmediate =>
                  x += 1; setImmediate =>
                    x += 1; setImmediate =>
                      x += 1; setImmediate =>
                        x += 1; setImmediate =>
                          cb(if x == 10 then null else 'error')


module.exports = (cb) ->
  cb null, benchmarks
