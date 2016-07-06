_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../src/token-manager'

describe 'TokenManager->verifyToken', ->
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

  describe 'when the token is expired', ->
    beforeEach (done) ->
      @datastore.insert
        uuid: 'superperson'
        hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='
        expiresOn: new Date(Date.now() - (1000 * 60))
        metadata:
          createdAt: new Date()
      , done

    beforeEach (done) ->
      @sut.verifyToken uuid: 'superperson', token: 'abc123', (error, @result) =>
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
