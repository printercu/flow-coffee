_       = require 'underscore'
flow    = require 'flow'
flow_c  = require '../flow'
async   = require 'async'
co      = require 'co'

bm_defaults =
  requests:   15000
  concurrent: 50
  type:       'async'

benchmarks = []

flow_bm = (flow) ->
  (cb) ->
    x = 0
    fn = -> setImmediate => @(x += 1)
    flow.exec(
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      -> cb(if x == 10 then null else 'error')
    )

flow_bm_multi = (flow) ->
  (cb) ->
    x = 0
    flow.exec(
      ->
        for i in [1..10]
          do (next = @MULTI()) => setImmediate => next(x += 1)
      -> cb(if x == 10 then null else 'error')
    )

benchmarks.push _.extend {}, bm_defaults,
  description:  'flow-coffee'
  method:       flow_bm flow_c

benchmarks.push _.extend {}, bm_defaults,
  description:  'flow-js'
  method:       flow_bm flow

benchmarks.push _.extend {}, bm_defaults,
  description:  'async'
  method:  (cb) ->
    x = 0
    fn = (a, cb) -> setImmediate => cb(null, x += 1)
    async.waterfall [
      (cb) -> setImmediate => cb(null, x += 1)
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      fn
      -> cb(if x == 10 then null else 'error')
    ]

benchmarks.push _.extend {}, bm_defaults,
  description:  'co'
  method:  (cb) ->
    x = 0
    fn = (callback) -> setImmediate -> callback null, x += 1
    co(`function*() {
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
      yield fn;
    }`) ->
      cb(if x == 10 then null else 'error')

benchmarks.push _.extend {}, bm_defaults,
  description:  'pure'
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

benchmarks.push _.extend {}, bm_defaults,
  description:  'flow-coffee multi'
  method:       flow_bm_multi flow_c

benchmarks.push _.extend {}, bm_defaults,
  description:  'flow-js multi'
  method:       flow_bm_multi flow

benchmarks.push _.extend {}, bm_defaults,
  description:  'co multi'
  method:  (cb) ->
    x = 0
    fn = (callback) -> setImmediate -> callback null, x += 1
    co(`function*() {
      yield [fn, fn, fn, fn, fn, fn, fn, fn, fn, fn]
    }`) ->
      cb(if x == 10 then null else 'error')

module.exports = (cb) ->
  cb null, benchmarks
