_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->checkTokenCache', ->
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

  describe 'when the cache is set', ->
    beforeEach (done) ->
      @cache.set 'spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', '', done

    it 'should have the token in the cache', (done) ->
      @sut.checkTokenCache {uuid: 'spiral', token: 'abc123'}, (error, result) =>
        return done error if error?
        expect(result).to.be.true
        done()

  describe 'when the cache is not set', ->
    beforeEach (done) ->
      @cache.set 'spiral:this-wont-work', '', done

    it 'should have the token in the cache', (done) ->
      @sut.checkTokenCache {uuid: 'spiral', token: 'abc123'}, (error, result) =>
        return done error if error?
        expect(result).to.be.false
        done()
