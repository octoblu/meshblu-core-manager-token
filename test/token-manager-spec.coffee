bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../src/token-manager'

describe 'TokenManager', ->
  beforeEach (done) ->
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @datastore = new Datastore
      database: mongojs 'token-manager-test'
      collection: 'things'
    @datastore.remove done

  beforeEach ->
    @sut = new TokenManager {@uuidAliasResolver, @datastore}

  describe '->revokeTokenByQuery', ->
    describe 'when a device with tagged tokens is inserted', ->
      beforeEach (done) ->
        device =
          uuid: 'spiral'
          meshblu:
            tokens:
              "U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU=":
                createdAt: "2015-12-28T16:55:22.459Z"
                tag: "hello"
              "PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8=":
                createdAt: "2015-12-28T16:55:30.183Z"
                tag: "hello"
        @datastore.insert device, done

      describe 'when called with a valid query', ->
        beforeEach (done) ->
          @sut.revokeTokenByQuery 'spiral', tag: 'hello', done

        it 'should not have any tokens', (done) ->
          @datastore.findOne uuid: 'spiral', (error, device) =>
            expect(device.meshblu.tokens["U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU="]).to.not.exist
            expect(device.meshblu.tokens["PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8="]).to.not.exist
            done()

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
        pepper = 'is super secret, ssshh'
        @sut = new TokenManager {@datastore,pepper,@uuidAliasResolver}

        @sut.verifyToken uuid: 'uuid', token: 'POPPED', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield true', ->
        expect(@result).to.be.true
