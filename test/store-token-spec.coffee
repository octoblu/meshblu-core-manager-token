_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../src/token-manager'

describe 'TokenManager->storeToken', ->
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

  beforeEach (done) ->
    @datastore.insert {uuid: 'spiral'}, done

  describe 'when called', ->
    beforeEach (done) ->
      @sut.storeToken { uuid: 'spiral', token: 'abc123' }, (error) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', (done) ->
        @sut._hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.hashedToken).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true
