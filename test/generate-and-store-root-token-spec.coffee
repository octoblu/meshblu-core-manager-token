_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->generateAndStoreRootToken', ->
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

  describe 'when called and the root token already exists', ->
    beforeEach (done) ->
      records = [
        {
          uuid: 'spiral'
          hashedToken: 'U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU='
          metadata:
            createdAt: new Date()
        }
        {
          uuid: 'spiral'
          hashedToken: 'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8='
          metadata:
            createdAt: new Date(Date.now() - (1000 * 60))
        }
        {
          uuid: 'spiral'
          hashedToken: 'bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA='
          hashedRootToken: 'this-is-something-crazy'
          metadata:
            createdAt: new Date()
        }
        {
          uuid: 'spiral'
          hashedToken: '921qQOxoW4JMEToonECV9he/6sR1TxKujAn84fFVCuM='
          hashedRootToken: 'this-is-something-crazy-2'
          metadata:
            createdAt: new Date()
        }
      ]

      @datastore.insert records, done

    describe 'when it really generates a token', ->
      beforeEach (done) ->
        @sut.generateAndStoreRootToken {uuid: 'spiral'}, (error, @generateToken) =>
          done error

      it 'should have a generated token', ->
        expect(@generateToken).to.exist

      it 'should be the old-hashed-token', ->
        expect(@generateToken).to.not.equal 'old-root-hashed-token'

    describe 'when it does not really generate a token', ->
      beforeEach (done) ->
        @sut._generateToken = sinon.stub()
        @sut._generateToken.returns 'this-the-real-token'
        @sut.generateAndStoreRootToken {uuid: 'spiral'}, (error, @generateToken) =>
          done error

      describe 'when the record is retrieved', ->
        beforeEach (done) ->
          @datastore.find { uuid: 'spiral' }, (error, @records) =>
            return done error if error?
            @record = _.find @records, (record) => record.hashedRootToken?
            done()

        it 'should only have one record', ->
          expect(_.compact(_.map(@records, 'hashedToken'))).to.deep.equal [
            'U4Q+LOkeTvMW/0eKg9MCvhWEFH2MTNhRhJQF5wLlGiU='
            'PEDXcLLHInRFO7ccxgtTwT8IxkJE6ECZsp6s9KF31x8=',
            'x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA='
          ]

        it 'should have a root hashed token', ->
          expect(@record.hashedRootToken).to.exist

        it 'should add a token to the datastore', ->
          expect(@record.hashedToken).to.equal 'x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA='

        it 'should match the generated token', (done) ->
          @sut._hashToken { uuid: 'spiral', token: 'this-the-real-token' }, (error, hashedToken) =>
            return done error if error?
            expect(@record.hashedToken).to.equal hashedToken
            done()

        it 'should match the generated root token', (done) ->
          @sut._verifyRootToken { token: 'this-the-real-token', hashedRootToken: @record.hashedRootToken }, (error, valid) =>
            return done error if error?
            expect(valid).to.be.true
            done()

        it 'should have the correct metadata in the datastore', ->
          expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

      it 'should add a token to the cache', (done) ->
        @cache.exists 'spiral:x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA=', (error, result) =>
          expect(result).to.be.true
          done()

      it 'should not have the old root tokens in the cache', (done) ->
        @cache.exists 'spiral:921qQOxoW4JMEToonECV9he/6sR1TxKujAn84fFVCuM=', (error, result) =>
          expect(result).to.be.false
          done()

      it 'should not have the old root tokens in the cache', (done) ->
        @cache.exists 'spiral:bOT5i3r4bUXvG5owgEVUBOtnF30zyuShfocALDoi1HA=', (error, result) =>
          expect(result).to.be.false
          done()

  describe 'when called and there are no tokens', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub()
      @sut._generateToken.returns 'this-the-real-token'
      @sut.generateAndStoreRootToken {uuid: 'spiral'}, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.find { uuid: 'spiral' }, (error, @records) =>
          return done error if error?
          @record = _.find @records, (record) => record.hashedRootToken?
          done()

      it 'should only have one record', ->
        expect(_.compact(_.map(@records, 'hashedToken'))).to.deep.equal [
          'x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA='
        ]

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA='

      it 'should have a root hashed token', ->
        expect(@record.hashedRootToken).to.exist

      it 'should match the generated token', (done) ->
        @sut._hashToken { uuid: 'spiral', token: 'this-the-real-token' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.hashedToken).to.equal hashedToken
          done()

      it 'should match the generated root token', (done) ->
        @sut._verifyRootToken { token: 'this-the-real-token', hashedRootToken: @record.hashedRootToken }, (error, valid) =>
          return done error if error?
          expect(valid).to.be.true
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

    it 'should add a token to the cache', (done) ->
      @cache.exists 'spiral:x3WkameywUX587Vuhr4I4U0F2rilHLW5aRh1xl5ZNIA=', (error, result) =>
        expect(result).to.be.true
        done()
