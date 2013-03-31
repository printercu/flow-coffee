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
          (results) ->
            assert.equal runs, times, "not enough runs: #{runs} of #{times}"
            assert.equal results.length, times, "results length does not match: #{results.length} != #{times}"
            @()
          cb
        )

    describe '#multi()', (cb) ->
      it 'should run all functions on current step even if some functions aren`t async', null, (cb) ->
        [runs, times] = [0, 10]
        flow.exec(
          ->
            for i in [1..times]
              do (cb = @multi()) -> cb null, ++runs
          (results) ->
            console.log results
            console.log runs
            assert.equal runs, times, "not enough runs: #{runs} of #{times}"
            assert.equal results.length, times, "results length does not match: #{results.length} != #{times}"
            @()
          cb
        )

  describe 'helpers:', ->
    describe 'anyError', ->
      it 'should be null if no error occured', (cb) ->
        flow.exec(
          ->
            do (cb = @multi()) -> nt -> cb null, 1, 2, 3
            do (cb = @multi 'test') -> nt -> cb null
          (results) ->
            assert.equal null, flow.anyError results
            @()
          cb
        )

      it 'should be not null on error', (cb) ->
        flow.exec(
          ->
            do (cb = @multi()) -> nt -> cb null, 1, 2, 3
            do (cb = @multi 'test') -> nt -> cb 'error'
            do (cb = @multi()) -> nt -> cb null
          (results) ->
            assert.notEqual null, flow.anyError results
            @()
          cb
        )

    describe 'returnIfAnyError', ->
      it 'should be false & should not call function if no error occured', (cb) ->
        called = false
        flow.exec(
          ->
            do (cb = @multi()) -> nt -> cb null, 1, 2, 3
            do (cb = @multi 'test') -> nt -> cb null
          (results) ->
            assert.equal false, flow.returnIfAnyError results, -> called = true
            assert.equal called, false
            @()
          cb
        )

      it 'should be true & should call function on error', (cb) ->
        called = false
        flow.exec(
          ->
            do (cb = @multi()) -> nt -> cb null, 1, 2, 3
            do (cb = @multi 'test') -> nt -> cb 'error'
            do (cb = @multi()) -> nt -> cb null
          (results) ->
            assert.equal true, flow.returnIfAnyError results, -> called = true
            assert.equal called, true
            @()
          cb
        )
