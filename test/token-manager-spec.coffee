bcrypt = require 'bcrypt'
crypto = require 'crypto'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../src/token-manager'

describe 'TokenManager', ->
  beforeEach (done) ->
    @datastore = new Datastore
      database: 'token-manager-test'
      collection: 'things'
    @datastore.remove done

  beforeEach ->
    @sut = new TokenManager
      datastore: @datastore

  describe '->verifyToken', ->
    describe 'when uuid "uuid" has the root token "MEAT GRINDER"', ->
      beforeEach (done) ->
        hashedMeatGrinder = '$2a$08$6BM2wY4bEmyIvQ7fjrh.zuXyYnahukgTjT4rWSH0Q6fRzIVDKafAW'

        @datastore.insert
          uuid: 'uuid'
          token: hashedMeatGrinder
        , done

      describe 'when called with the correct token', ->
        beforeEach (done) ->
          @sut.verifyToken uuid: 'uuid', token: 'MEAT GRINDER', (@error, @result) => done()

        it 'should yield no error', ->
          expect(@error).not.to.exist

        it 'should yield true', ->
          expect(@result).to.be.true

      describe 'when called with the incorrect token', ->
        beforeEach (done) ->
          @sut.verifyToken uuid: 'uuid', token: 'incorrect', (@error, @result) => done()

        it 'should yield no error', ->
          expect(@error).not.to.exist

        it 'should yield false', ->
          expect(@result).to.be.false

    describe 'when called with an invalid uuid', ->
      beforeEach (done) ->
        @sut.verifyToken uuid: 'uuid', token: 'token', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield false', ->
        expect(@result).to.be.false

    describe 'when the root token is invalid', ->
      beforeEach (done) ->
        @datastore.insert
          uuid: 'uuid'
          token: 'not-even-a-hash'
        , done

      beforeEach (done) ->
        @sut.verifyToken uuid: 'uuid', token: 'invalid', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield false', ->
        expect(@result).to.be.false

    describe 'when uuid "uuid" has the session token "POPPED"', ->
      beforeEach (done) ->
        hashedPOPPED = 'EdZOPunc/qlzKS4VwCSH3qk2Ite3xPuXN/jeh6HMB9g='
        record =
          uuid: 'uuid'
          token: ''
          meshblu:
            tokens: {}

        record.meshblu.tokens[hashedPOPPED] = createdAt: 'whenever'
        @datastore.insert record, done

      beforeEach (done) ->
        @sut = new TokenManager
          datastore: @datastore
          pepper: 'is super secret, ssshh'

        @sut.verifyToken uuid: 'uuid', token: 'POPPED', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield true', ->
        expect(@result).to.be.true
