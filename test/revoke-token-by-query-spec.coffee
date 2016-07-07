_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../'

describe 'TokenManager->revokeTokenByQuery', ->
  beforeEach (done) ->
    @pepper = 'im-a-pepper'
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    database = mongojs 'token-manager-test', ['things']
    @datastore = new Datastore
      database: database
      collection: 'things'
    database.things.remove done

  beforeEach ->
    @sut = new TokenManager {@uuidAliasResolver, @datastore, @pepper}

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
      ]
      @datastore.insert records, done

    describe 'when called with a valid query', ->
      beforeEach (done) ->
        @sut.revokeTokenByQuery {uuid: 'spiral', query: {tag: 'hello'}}, (error) =>
          done error

      it 'should have no tokens', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          expect(records.length).to.equal 0
          done()

    describe 'when called with a date query', ->
      beforeEach (done) ->
        thirtySecondsAgo = new Date(Date.now() - (1000 * 30))
        @sut.revokeTokenByQuery { uuid: 'spiral', query: createdAt: { $gt: thirtySecondsAgo } }, (error) =>
          done error

      it 'should have only one token', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
            'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          ]
          done()

    describe 'when called with a complex query', ->
      beforeEach (done) ->
        @sut.revokeTokenByQuery {uuid: 'spiral', query: { services: { $in: ['super'] } }}, (error) =>
          done error

      it 'should have no tokens', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          expect(records.length).to.equal 1
          done()

    describe 'when called with a weird key value in the query', ->
      beforeEach (done) ->
        @sut.revokeTokenByQuery {uuid: 'spiral', query: { "something crazy yes" : true }}, (error) =>
          done error

      it 'should have no tokens', (done) ->
        @datastore.find { uuid: 'spiral' }, (error, records) =>
          expect(records.length).to.equal 2
          done()
