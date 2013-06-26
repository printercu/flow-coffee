assert  = require 'assert'
flow    = require '../flow'
nt      = setImmediate

describe 'Flow', ->
  describe '#define()', ->
    it 'returns a function ', ->
      assert.equal 'function', typeof flow.define()

    it 'runs the flow', (done) ->
      x = []
      f = flow.define(
        -> nt => @ x.push 1
        -> nt => @ x.push 2
        -> @ assert.deepEqual x, [1, 2]
        done
      )
      f()

    it 'reruns the flow', (done) ->
      x = []
      f = flow.define(
        -> nt => @ x.push 1
        -> nt => @ x.push 2
      )
      f()
      f()
      do wait = -> nt ->
        return wait() unless x.length == 4
        done()

  describe '#exec()', ->
    it 'runs serial functions', (done) ->
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
        done
      )

    it 'runs serial not async functions', (done) ->
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
        done
      )

    it 'passes arguments', (done) ->
      flow.exec(
        -> @ 1, 2
        (x, y) ->
          assert.equal x, 1
          assert.equal y, 2
          @()
        done
      )

  describe '#multi()', ->
    it 'runs all functions on current step', (done) ->
      [runs, times] = [0, 10]
      flow.exec(
        ->
          for i in [1..times]
            do (cb = @multi()) -> nt -> cb null, ++runs
        (err, results) ->
          assert.equal runs, times, "not enough runs: #{runs} of #{times}"
          assert.equal results.length, times, "results length does not match: #{results.length} != #{times}"
          @()
        done
      )

    it 'calls next function with first occured error as first argument', (done) ->
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
        done
      )

    it 'preserves results order', (done) ->
      run = []
      flow.exec(
        ->
          do (cb = @multi()) -> nt -> nt -> run.push 1; cb 1
          do (cb = @multi()) -> nt ->       run.push 2; cb 2
        (err, results)->
          assert.deepEqual run, [2, 1]
          assert.deepEqual (x[0] for x in results), [1, 2]
          @()
        done
      )

    # TODO:
    it 'runs all functions on current step even if some functions aren`t async', null, (done) ->
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
        done
      )

    it 'throws exception when calling next() in multi mode', (done) ->
      flow.exec(
        ->
          nt => assert.throws => @()
          do (cb = @multi()) -> nt -> cb()
        done
      )

  describe '#error', ->
    it 'runs only error callback on error if present', (done) ->
      flow.exec(
        -> nt => @ 'err'
        -> assert false, 'should not be run'
      ).error (err) ->
        assert.equal err, 'err'
        done()

    it 'runs only error callback on error if present in multi mode', (done) ->
      flow.exec(
        ->
          do (cb = @multi()) -> nt -> cb null
          do (cb = @multi()) -> nt -> cb 'err'
        -> assert false, 'should not be run'
      ).error (err) ->
        assert.equal err, 'err'
        done()

    it 'resumes flow', (done) ->
      run = false
      flow.exec(
        -> nt => @ 'err'
        ->
          assert run
          @()
        done
      ).error (err) ->
        assert.equal err, 'err'
        run = true
        @()

    it 'strips first argument for usual callbacks', (done) ->
      flow.exec(
        (args...) ->
          assert.deepEqual args, []
          nt => @ null, 1, 2
        (args...) ->
          assert.deepEqual args, [1, 2]
          nt => @ 'err', 3, 4
        (args...) -> done assert.deepEqual args, [5, 6]
      ).error (err, args...) ->
        assert.equal err, 'err'
        assert.deepEqual args, [3, 4]
        @(null, 5, 6)

  context 'when context is given', ->
    it 'runs all the functions in this context', (done) ->
      obj = a: 1
      run = 0
      multi = 3
      err_run = 0
      new flow(
        blocks: [
          (args..., cb) ->
            assert.deepEqual @, obj
            assert.deepEqual args, [1, 2, 3]
            nt -> cb()
          (cb) ->
            assert.deepEqual @, obj
            for i in [1..multi]
              do (cb = cb.multi(), i) -> nt ->
                run += 1
                cb(null, i)
          (results, cb) ->
            assert.deepEqual @, obj
            for item, i in [[null, 1], [null, 2], [null, 3]]
              assert.deepEqual Array::slice.call(results[i]), item
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

    it 'interprets strings as context`s methods', (done) ->
      obj =
        method: (cb) -> nt -> cb 'error'
        other_method: -> done()
        error: (err, cb) -> cb()
      do new flow
        blocks: [
          'method'
          'other_method'
        ]
        error:    'error'
        context:  obj

    context 'when error callback is not set', ->
      it 'does not strip first argument', (done) ->
        obj = a: 1
        do new flow
          context: obj
          blocks: [
            (args..., cb) ->
              assert.deepEqual args, []
              cb(1, 2)
            (args..., cb) ->
              assert.deepEqual args, [1, 2]
              cb(null)
            (args..., cb) ->
              assert.deepEqual args, [null]
              cb
              done()
          ]

  describe '`final` callback', ->
    it 'runs last', (done) ->
      runs = []
      do new flow
        final: -> done assert.deepEqual runs, [1, 2]
        blocks: [
          -> runs.push 1; @()
          -> nt => runs.push 2; @()
        ]

  describe '#after', ->
    it 'appends blocks in reverse order', (done) ->
      runs = []
      do new flow
        blocks: [
          ->
            runs.push 1
            @after ->
              runs.push 5
              nt @
            nt @
          ->
            runs.push 2
            @after ->
              runs.push 4
              nt @
            nt @
          ->
            runs.push 3
            nt @
        ]
        final: ->
          assert.deepEqual runs, [1..5]
          done()
