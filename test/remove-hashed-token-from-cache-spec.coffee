_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->removeHashedTokenFromCache', ->
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
    @cache.set "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", '', done

  beforeEach (done) ->
    @sut.removeHashedTokenFromCache uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', done

  it 'should remove the token from the cache', (done) ->
    @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
      expect(result).to.be.false
      done()
