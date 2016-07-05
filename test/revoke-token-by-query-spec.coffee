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
          hashedToken: 'U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU='
          metadata:
            createdAt: new Date()
            tag: 'hello'
        }
        {
          uuid: 'spiral'
          hashedToken: 'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          metadata:
            createdAt: new Date(Date.now() - (1000 * 60))
            services: ['super', 'lame', 'awesome']
            tag: 'hello'
        }
        {
          uuid: 'spiral'
          hashedToken: 'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          hashedRootToken: 'this-is-something-crazy'
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
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
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

    describe 'when called with a date query', ->
      beforeEach (done) ->
        thirtySecondsAgo = new Date(Date.now() - (1000 * 30))
        @sut.revokeTokenByQuery { uuid: 'spiral', query: createdAt: { $gt: thirtySecondsAgo } }, (error) =>
          done error

      it 'should have only the root token', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
            'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
            'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          ]
          done()

      it 'should remove the token 1 from the cache', (done) ->
        @cache.exists 'spiral:U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU=', (error, result) =>
          expect(result).to.be.false
          done()

    describe 'when called with a complex query', ->
      beforeEach (done) ->
        thirtySecondsAgo = new Date(Date.now() - (1000 * 30))
        @sut.revokeTokenByQuery {uuid: 'spiral', query: { services: { $in: ['super'] } }}, (error) =>
          done error

      it 'should have only the root token', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
            'U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU='
            'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          ]
          done()

      it 'should remove the token 1 from the cache', (done) ->
        @cache.exists 'spiral:PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8=', (error, result) =>
          expect(result).to.be.false
          done()
