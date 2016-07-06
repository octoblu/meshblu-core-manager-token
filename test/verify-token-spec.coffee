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

  describe 'when called with an invalid uuid', ->
    beforeEach (done) ->
      @sut.verifyToken uuid: 'not-supergirl', token: 'token', (error, @result) =>
        done error

    it 'should yield false', ->
      expect(@result).to.be.false

  describe 'when the token is invalid', ->
    beforeEach (done) ->
      @datastore.insert
        uuid: 'superperson'
        hashedToken: 'not-even-a-hash'
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
        hashedToken: 'd5/NnLFR29SDb6d7AXTj8Jx+efETnN1JBQaknjF6vDA='
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
