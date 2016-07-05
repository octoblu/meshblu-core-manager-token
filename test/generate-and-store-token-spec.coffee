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
      @sut.generateToken = sinon.stub().returns('abc123')
      @sut.generateAndStoreToken uuid: 'spiral', (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', token: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.token).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', (done) ->
        @sut.hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.token).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

      it 'should be a session token', ->
        expect(@record.root).to.be.false

    it 'should add a token to the cache', (done) ->
      @cache.exists 'spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', (error, result) =>
        expect(result).to.be.true
        done()

  describe 'when called with options', ->
    beforeEach (done) ->
      @sut.generateToken = sinon.stub().returns('abc123')
      data =
        tag: 'foo'
      @sut.generateAndStoreToken {uuid: 'spiral', data}, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', token: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.token).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', (done) ->
        @sut.hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.token).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(@record.metadata.tag).to.equal 'foo'
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

      it 'should be a session token', ->
        expect(@record.root).to.be.false

    it 'should add a token to the cache', (done) ->
      @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
        expect(result).to.be.true
        done()
