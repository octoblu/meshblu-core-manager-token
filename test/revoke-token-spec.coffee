{describe,beforeEach,it,expect} = global
_         = require 'lodash'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../'

describe 'TokenManager->revokeToken', ->
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
          hashedToken: 'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          metadata:
            createdAt: new Date()
        }
      ]

      @datastore.insert records, done

    describe 'when called with a valid query', ->
      beforeEach (done) ->
        @sut.revokeToken {uuid: 'spiral', token: 'abc123'}, done

      it 'should have only the token', (done) ->
        @datastore.find uuid: 'spiral', (error, records) =>
          hashedTokens = _.map records, 'hashedToken'
          expect(hashedTokens).to.deep.equal [
            'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          ]
          done()
