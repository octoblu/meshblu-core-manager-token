_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->revokeTokenByQuery', ->
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

  describe 'when tagged tokens are inserted', ->
    beforeEach (done) ->
      records = [
        {
          uuid: 'spiral'
          token: 'U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU='
          root: false
          metadata:
            createdAt: new Date()
            tag: 'hello'
        }
        {
          uuid: 'spiral'
          token: 'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          root: false
          metadata:
            createdAt: new Date()
            tag: 'hello'
        }
        {
          uuid: 'spiral'
          token: 'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          root: true
          metadata:
            createdAt: new Date()
            tag: 'hello'
        }
      ]
      @datastore.insert records, done

    beforeEach (done) ->
      @cache.set "spiral:U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU=", 'set', done

    beforeEach (done) ->
      @cache.set "spiral:PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8=", 'set', done

    describe 'when called with a valid query', ->
      beforeEach (done) ->
        @sut.revokeTokenByQuery {uuid: 'spiral', query: {tag: 'hello'}}, (error) =>
          done error

      it 'should have only the root token', (done) ->
        @datastore.find {uuid: 'spiral', 'metadata.tag': 'hello' }, (error, records) =>
          tokens = _.map records, 'token'
          expect(tokens).to.deep.equal [
            'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          ]
          done()

      it 'should remove the token 1 from the cache', (done) ->
        @cache.exists 'spiral:U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU=', (error, result) =>
          expect(result).to.be.false
          done()

      it 'should remove the token 2 from the cache', (done) ->
        @cache.exists 'spiral:PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8=', (error, result) =>
          expect(result).to.be.false
          done()
