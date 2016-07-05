_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager', ->
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

  describe '->generateAndStoreTokenInCache', ->

    describe 'when called without options', ->
      beforeEach (done) ->
        @sut.generateToken = sinon.stub().returns('abc123')
        @sut.generateAndStoreTokenInCache uuid: 'spiral', done

      it 'should add a token to the cache', (done) ->
        @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
          expect(result).to.be.true
          done()

    describe 'when called with options', ->
      beforeEach (done) ->
        @sut.generateToken = sinon.stub().returns('abc123')
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

  describe '->generateAndStoreToken', ->
    beforeEach (done) ->
      @datastore.insert {uuid: 'spiral'}, done

    describe 'when called without options', ->
      beforeEach (done) ->
        @sut.generateToken = sinon.stub().returns('abc123')
        @sut.generateAndStoreToken uuid: 'spiral', (error, @generateToken) =>
          done error

      describe 'when the record is retrieved', ->
        beforeEach (done) ->
          @datastore.findOne { uuid: 'spiral', token: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
            done error

        it 'should add a token to the datastore', ->
          expect(@record.token).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

        it 'should match the generated token', (done) ->
          @sut.hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
            return done error if error?
            expect(@record.token).to.equal hashedToken
            done()

        it 'should have the correct metadata in the datastore', ->
          expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

        it 'should be a session token', ->
          expect(@record.root).to.be.false

      it 'should add a token to the cache', (done) ->
        @cache.exists 'spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', (error, result) =>
          expect(result).to.be.true
          done()

    describe 'when called with options', ->
      beforeEach (done) ->
        @sut.generateToken = sinon.stub().returns('abc123')
        data =
          tag: 'foo'
        @sut.generateAndStoreToken {uuid: 'spiral', data}, (error, @generateToken) =>
          done error

      describe 'when the record is retrieved', ->
        beforeEach (done) ->
          @datastore.findOne { uuid: 'spiral', token: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
            done error

        it 'should add a token to the datastore', ->
          expect(@record.token).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

        it 'should match the generated token', (done) ->
          @sut.hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
            return done error if error?
            expect(@record.token).to.equal hashedToken
            done()

        it 'should have the correct metadata in the datastore', ->
          expect(@record.metadata.tag).to.equal 'foo'
          expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

        it 'should be a session token', ->
          expect(@record.root).to.be.false

      it 'should add a token to the cache', (done) ->
        @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
          expect(result).to.be.true
          done()

  describe '->removeHashedTokenFromCache', ->
    beforeEach (done) ->
      @cache.set "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", '', done

    beforeEach (done) ->
      @sut.removeHashedTokenFromCache uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=', done

    it 'should remove the token from the cache', (done) ->
      @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
        expect(result).to.be.false
        done()

  describe '->removeHashedTokenFromCache', ->
    beforeEach (done) ->
      @cache.set "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", '', done

    beforeEach (done) ->
      @sut.removeTokenFromCache uuid: 'spiral', token: 'abc123', done

    it 'should remove the token from the cache', (done) ->
      @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
        expect(result).to.be.false
        done()

  describe '->revokeToken', ->
    describe 'when tokens are inserted', ->
      beforeEach (done) ->
        records = [
          {
            uuid: 'spiral'
            token: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='
            root: false
            metadata:
              createdAt: new Date()
          }
          {
            uuid: 'spiral'
            token: 'GQv7F9G0GsV3JvEewG+FDkE2G0dGKAi7/W3Ss7QQmgI='
            root: true
            metadata:
              createdAt: new Date()
          }
        ]

        @datastore.insert records, done

      beforeEach (done) ->
        @cache.set "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", 'set', done

      describe 'when called with a valid query', ->
        beforeEach (done) ->
          @sut.revokeToken uuid: 'spiral', token: 'abc123', done

        it 'should have only the token', (done) ->
          @datastore.find uuid: 'spiral', (error, records) =>
            tokens = _.map records, 'token'
            expect(tokens).to.deep.equal [
              'GQv7F9G0GsV3JvEewG+FDkE2G0dGKAi7/W3Ss7QQmgI='
            ]
            done()

        it 'should remove the token 1 from the cache', (done) ->
          @cache.exists "spiral:T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=", (error, result) =>
            expect(result).to.be.false
            done()

  describe '->revokeTokenByQuery', ->
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

  describe '->verifyToken', ->
    describe 'when uuid "uuid" has the root token "MEAT GRINDER"', ->
      beforeEach (done) ->
        record =
          uuid: 'supergirl'
          token: '$2a$08$6BM2wY4bEmyIvQ7fjrh.zuXyYnahukgTjT4rWSH0Q6fRzIVDKafAW'
          root: true
          metadata:
            createdAt: new Date()
        @datastore.insert record, done

      describe 'when called with the correct token', ->
        beforeEach (done) ->
          @sut.verifyToken uuid: 'supergirl', token: 'MEAT GRINDER', (error, @result) =>
            done error

        it 'should yield true', ->
          expect(@result).to.be.true

      describe 'when called with the incorrect token', ->
        beforeEach (done) ->
          @sut.verifyToken uuid: 'supergirl', token: 'incorrect', (error, @result) =>
            done error

        it 'should yield false', ->
          expect(@result).to.be.false

    describe 'when called with an invalid uuid', ->
      beforeEach (done) ->
        @sut.verifyToken uuid: 'not-supergirl', token: 'token', (error, @result) =>
          done error

      it 'should yield false', ->
        expect(@result).to.be.false

    describe 'when the root token is invalid', ->
      beforeEach (done) ->
        @datastore.insert
          uuid: 'superperson'
          token: 'not-even-a-hash'
          root: true
          metadata:
            createdAt: new Date()
        , done

      beforeEach (done) ->
        @sut.verifyToken uuid: 'superperson', token: 'invalid', (error, @result) =>
          done error

      it 'should yield false', ->
        expect(@result).to.be.false

    describe 'when uuid "uuid" has the session token "POPPED"', ->
      beforeEach (done) ->
        record =
          uuid: 'superman'
          token: 'd5/NnLFR29SDb6d7AXTj8Jx+efETnN1JBQaknjF6vDA='
          root: false
          metadata:
            createdAt: new Date()

        @datastore.insert record, done

      beforeEach (done) ->
        pepper = 'is super secret, ssshh'
        @sut = new TokenManager {@datastore,pepper,@uuidAliasResolver}

        @sut.verifyToken {uuid: 'superman', token: 'POPPED'}, (error, @result) =>
          done error

      it 'should yield true', ->
        expect(@result).to.be.true
