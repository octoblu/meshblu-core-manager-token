_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
uuid      = require 'uuid'
redis     = require 'fakeredis'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
Cache     = require 'meshblu-core-cache'

TokenManager = require '../src/token-manager'

describe 'TokenManager->verifyToken', ->
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
