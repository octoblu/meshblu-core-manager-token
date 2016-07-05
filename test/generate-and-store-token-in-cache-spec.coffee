_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->generateAndStoreTokenInCache', ->
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

  describe 'when called without options', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns('abc123')
      @sut.generateAndStoreTokenInCache uuid: 'spiral', done

    it 'should add a token to the cache', (done) ->
      @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
        expect(result).to.be.true
        done()

  describe 'when called with options', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns('abc123')
      @sut.generateAndStoreTokenInCache uuid: 'spiral', expireSeconds: 1, done

    it 'should add a token to the cache', (done) ->
      @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
        expect(result).to.be.true
        done()

    it 'should expire the token in 1 second', (done)->
      @cache.ttl "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, ttl) =>
        return done error if error?
        expect(ttl).to.equal 1
        done()
