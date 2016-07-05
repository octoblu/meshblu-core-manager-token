_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->revokeToken', ->
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

  describe 'when tokens are inserted', ->
    beforeEach (done) ->
      records = [
        {
          uuid: 'spiral'
          hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='
          metadata:
            createdAt: new Date()
        }
        {
          uuid: 'spiral'
          hashedToken: 'GQv7F9G0GsV3JvEewG+FDkE2G0dGKAi7/W3Ss7QQmgI='
          hashedRootToken: 'this-is-something-crazy'
          metadata:
            createdAt: new Date()
        }
      ]

      @datastore.insert records, done

    beforeEach (done) ->
      @cache.set "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", 'set', done

    describe 'when called with a valid query', ->
      beforeEach (done) ->
        @sut.revokeToken {uuid: 'spiral', token: 'abc123'}, done

      it 'should have only the token', (done) ->
        @datastore.find uuid: 'spiral', (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
            'GQv7F9G0GsV3JvEewG+FDkE2G0dGKAi7/W3Ss7QQmgI='
          ]
          done()

      it 'should remove the token 1 from the cache', (done) ->
        @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
          expect(result).to.be.false
          done()
