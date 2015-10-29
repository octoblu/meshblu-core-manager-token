bcrypt = require 'bcrypt'
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

      beforeEach (done) ->
        @sut.verifyToken uuid: 'uuid', token: 'MEAT GRINDER', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield true', ->
        expect(@result).to.be.true

    describe 'when called with an invalid uuid', ->
      beforeEach (done) ->
        @sut.verifyToken uuid: 'uuid', token: 'token', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield false', ->
        expect(@result).to.be.false

    describe 'when called with an invalid token', ->
      beforeEach (done) ->
        hashedMeatGrinder = '$2a$08$6BM2wY4bEmyIvQ7fjrh.zuXyYnahukgTjT4rWSH0Q6fRzIVDKafAW'

        @datastore.insert
          uuid: 'uuid'
          token: hashedMeatGrinder
        , done

      beforeEach (done) ->
        @sut.verifyToken uuid: 'uuid', token: 'invalid', (@error, @result) => done()

      it 'should yield no error', ->
        expect(@error).not.to.exist

      it 'should yield false', ->
        expect(@result).to.be.false
