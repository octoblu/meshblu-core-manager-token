{describe,beforeEach,it,expect} = global
_             = require 'lodash'
mongojs       = require 'mongojs'
Datastore     = require 'meshblu-core-datastore'
TokenManager = require '..'

describe 'Search Tokens', ->
  beforeEach (done) ->
    database = mongojs 'token-manager-test', ['tokens']
    @datastore = new Datastore
      database: database
      collection: 'tokens'

    database.tokens.remove done

  beforeEach ->
    @pepper = 'im-a-pepper'
    @uuidAliasResolver = resolve: (uuid, callback) => callback(null, uuid)
    @sut = new TokenManager {@datastore, @uuidAliasResolver, @pepper}

  describe 'when called without a uuid', ->
    beforeEach (done) ->
      @sut.search {uuid: null}, (@error) => done()

    it 'should have an error', ->
      expect(@error.message).to.equal 'Missing uuid'

  describe 'basic search', ->
    beforeEach (done) ->
      tokens = [
        {
          uuid: 'darth-vader'
          metadata:
            tag: 'light-saber'
        },
        {
          uuid: 'darth-vader'
          metadata:
            tag: 'dark-saber'
        }
      ]
      @datastore.insert tokens, done

    describe 'when called with no query', ->
      beforeEach (done) ->
        @sut.search uuid: 'darth-vader', (error, @tokens) => done error

      it 'should return 2 tokens', ->
        expect(@tokens.length).to.equal 2

      it 'should return the correct tokens', ->
        expect(@tokens).to.containSubset [
          {metadata: tag: 'light-saber'}
          {metadata: tag: 'dark-saber'}
        ]
        expect(_.first(@tokens).type).to.not.exist

      it 'should not have the actual token', ->
        _.each @tokens, (token) =>
          expect(token.hashedToken).to.be.undefined

    describe 'when called with a dot notated projection', ->
      beforeEach (done) ->
        @sut.search uuid: 'darth-vader', query: {'metadata.tag': 'dark-saber'}, (error, @tokens) => done error

      it 'should return 1 tokens', ->
        expect(@tokens.length).to.equal 1

    describe 'when called with a non-matching query', ->
      beforeEach (done) ->
        @sut.search uuid: 'darth-vader', query: {superman: true}, (error, @tokens) => done error

      it 'should return 0 tokens', ->
        expect(@tokens.length).to.equal 0
