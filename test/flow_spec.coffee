assert  = require 'assert'
flow    = require '../flow'
nt      = process.nextTick

describe 'flow', ->
  describe '#define()', ->
    it 'should return a function ', ->
      assert.equal 'function', typeof flow.define()

    it 'should run the flow', (cb) ->
      x = []
      f = flow.define(
        -> nt => @ x.push 1
        -> nt => @ x.push 2
        -> @ assert.deepEqual x, [1, 2]
        cb
      )
      f()

    it 'should rerun the flow', (cb) ->
      x = []
      f = flow.define(
        -> nt => @ x.push 1
        -> nt => @ x.push 2
      )
      f()
      f()
      do wait = -> nt ->
        return wait() unless x.length == 4
        cb()

  describe '#exec()', ->
    it 'should run serial functions', (cb) ->
      x = []
      flow.exec(
        ->
          nt => @ x.push 1
          assert.deepEqual x, []
        (l) ->
          assert.equal x.length, l
          nt => @ x.push 2
          assert.deepEqual x, [1]
        (l) ->
          assert.equal x.length, l
          @ assert.deepEqual x, [1, 2]
        cb
      )

    it 'should run serial not async functions', (cb) ->
      x = []
      flow.exec(
        ->
          @ x.push 1
          assert.deepEqual x, [1]
        (l) ->
          assert.equal x.length, l
          @ x.push 2
          assert.deepEqual x, [1, 2]
        (l) ->
          assert.equal x.length, l
          @ assert.deepEqual x, [1, 2]
        cb
      )

    it 'should pass arguments', (cb) ->
      flow.exec(
        -> @ 1, 2
        (x, y) ->
          assert.equal x, 1
          assert.equal y, 2
          @()
        cb
      )

  describe '#multi()', (cb) ->
    it 'should run all functions on current step', (cb) ->
      [runs, times] = [0, 10]
      flow.exec(
        ->
          for i in [1..times]
            do (cb = @multi()) -> nt -> cb null, ++runs
        (err, results) ->
          assert.equal runs, times, "not enough runs: #{runs} of #{times}"
          assert.equal results.length, times, "results length does not match: #{results.length} != #{times}"
          @()
        cb
      )

    it 'should call next function with first occured error as first argument', (cb) ->
      flow.exec(
        ->
          do (cb = @multi()) -> nt -> cb null
          do (cb = @multi()) -> nt -> cb 'err'
          do (cb = @multi()) -> nt -> cb null
        (err, results) ->
          assert.equal err, 'err'
          do (cb = @multi()) -> nt -> cb null
          do (cb = @multi()) -> nt -> cb null
        (err, results) ->
          assert.equal err, null
          @()
        cb
      )

    it 'should preserve results order', (cb) ->
      run = []
      flow.exec(
        ->
          do (cb = @multi()) -> nt -> nt -> run.push 1; cb 1
          do (cb = @multi()) -> nt ->       run.push 2; cb 2
        (err, results)->
          assert.deepEqual run, [2, 1]
          assert.deepEqual (x[0] for x in results), [1, 2]
          @()
        cb
      )

    # TODO:
    it 'should run all functions on current step even if some functions aren`t async', null, (cb) ->
      [runs, times] = [0, 10]
      flow.exec(
        ->
          for i in [1..times]
            do (cb = @multi()) -> cb null, ++runs
        (err, results) ->
          console.log results
          console.log runs
          assert.equal runs, times, "not enough runs: #{runs} of #{times}"
          assert.equal results.length, times, "results length does not match: #{results.length} != #{times}"
          @()
        cb
      )

  describe '#error', ->
    it 'should run only error callback on error if present', (cb) ->
      flow.exec(
        -> nt => @ 'err'
        -> assert false, 'should not be run'
      ).error (err) ->
        assert.equal err, 'err'
        cb()

    it 'should run only error callback on error if present in multi mode', (cb) ->
      flow.exec(
        ->
          do (cb = @multi()) -> nt -> cb null
          do (cb = @multi()) -> nt -> cb 'err'
        -> assert false, 'should not be run'
      ).error (err) ->
        assert.equal err, 'err'
        cb()

    it 'should resume flow', (cb) ->
      run = false
      flow.exec(
        -> nt => @ 'err'
        ->
          assert run
          @()
        cb
      ).error (err) ->
        assert.equal err, 'err'
        run = true
        @()

  describe 'when context is given', ->
    it 'should run all the functions in this context', (done) ->
      obj = {a: 1}
      run = 0
      multi = 3
      err_run = 0
      new flow(
        blocks: [
          (args..., cb) ->
            assert.deepEqual @, obj
            assert.deepEqual args, [null, 1, 2, 3]
            nt ->
              cb()
          (cb) ->
            assert.deepEqual @, obj
            for i in [1..multi]
              do (cb = cb.multi()) -> nt ->
                run += 1
                cb()
          (err, results, cb) ->
            assert.deepEqual @, obj
            nt -> cb 'error'
          ->
            assert.deepEqual @, obj
            assert.equal run, multi
            assert.equal err_run, 1
            done()
        ]
        error: (args..., cb) ->
          assert.deepEqual @, obj
          err_run += 1
          cb(null)
        context: obj
      )(null, 1, 2, 3)

    it 'should interpret strings as context`s methods', (done) ->
      obj =
        method: (cb) -> nt -> cb 'error'
        other_method: -> done()
        error: (err, cb) -> cb()
      do new flow(
        blocks: [
          'method'
          'other_method'
        ]
        error: 'error'
        context: obj
      )
