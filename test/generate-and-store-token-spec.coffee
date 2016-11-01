_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->generateAndStoreToken', ->
  beforeEach (done) ->
    @redisKey = uuid.v1()
    @pepper = 'im-a-pepper'
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    database = mongojs 'token-manager-test', ['things']
    @datastore = new Datastore
      database: database
      collection: 'things'
    @cache = new Cache
      client: redis.createClient @redisKey
    database.things.remove done

  beforeEach ->
    @sut = new TokenManager {@uuidAliasResolver, @datastore, @cache, @pepper}

  beforeEach (done) ->
    @datastore.insert {uuid: 'spiral'}, done

  describe 'when called without options', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns 'abc123'
      @sut.generateAndStoreToken {uuid: 'spiral'}, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', ->
        hashedToken = @sut.hashToken { uuid: 'spiral', token: 'abc123' }
        expect(@record.hashedToken).to.equal hashedToken

      it 'should have the correct metadata in the datastore', ->
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

    it 'should add a token to the cache', (done) ->
      @cache.exists 'spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', (error, result) =>
        expect(result).to.be.true
        done()

  describe 'when called with options', ->
    describe 'when called with metadata', ->
      beforeEach (done) ->
        @sut._generateToken = sinon.stub().returns('abc123')
        metadata =
          tag: 'foo'
        @sut.generateAndStoreToken {uuid: 'spiral', metadata}, (error, @generateToken) =>
          done error

      describe 'when the record is retrieved', ->
        beforeEach (done) ->
          @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
            done error

        it 'should add a hashedToken to the datastore', ->
          expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

        it 'should match the generated token', ->
          hashedToken = @sut.hashToken { uuid: 'spiral', token: 'abc123' }
          expect(@record.hashedToken).to.equal hashedToken

        it 'should have the correct metadata in the datastore', ->
          expect(@record.metadata.tag).to.equal 'foo'
          expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

      it 'should add a token to the cache', (done) ->
        @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
          expect(result).to.be.true
          done()

    describe 'when called with data (backwards compability)', ->
      beforeEach (done) ->
        @sut._generateToken = sinon.stub().returns('abc123')
        data =
          tag: 'foo'
        @sut.generateAndStoreToken {uuid: 'spiral', data}, (error, @generateToken) =>
          done error

      describe 'when the record is retrieved', ->
        beforeEach (done) ->
          @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
            done error

        it 'should add a token to the datastore', ->
          expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

        it 'should match the generated hashedToken', ->
          hashedToken = @sut.hashToken { uuid: 'spiral', token: 'abc123' }
          expect(@record.hashedToken).to.equal hashedToken

        it 'should have the correct metadata in the datastore', ->
          expect(@record.metadata.tag).to.equal 'foo'
          expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

      it 'should add a token to the cache', (done) ->
        @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
          expect(result).to.be.true
          done()
