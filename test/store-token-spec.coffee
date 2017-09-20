{describe,beforeEach,it,expect} = global
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../'

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

      it 'should not add a root to the datastore', ->
        expect(@record.root).to.not.exist

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', ->
        hashedToken = @sut._hashToken { uuid: 'spiral', token: 'abc123' }
        expect(@record.hashedToken).to.equal hashedToken

  describe 'when called and the token already exists', ->
    beforeEach (done) ->
      @sut.storeToken { uuid: 'spiral', token: 'abc123' }, (error) =>
        done error

    beforeEach (done) ->
      @sut.storeToken { uuid: 'spiral', token: 'abc123' }, (error) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.find { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @records) =>
          done error

      it 'should only have one', ->
        expect(@records.length).to.equal 1

  describe 'when called with an expiresON', ->
    beforeEach (done) ->
      @expiresOn = new Date()
      @sut.storeToken { uuid: 'spiral', token: 'abc123', @expiresOn }, (error) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should not add a root to the datastore', ->
        expect(@record.root).to.not.exist

      it 'should add a expiresOn to the datastore', ->
        expect(@record.expiresOn).to.deep.equal @expiresOn

      it 'should match the generated token', ->
        hashedToken = @sut._hashToken { uuid: 'spiral', token: 'abc123' }
        expect(@record.hashedToken).to.equal hashedToken

  describe 'when called with root: true', ->
    beforeEach (done) ->
      @expiresOn = new Date()
      @sut.storeToken { uuid: 'spiral', token: 'abc123', root: true }, (error) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', root: true }, (error, @record) =>
          done error

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should add a root to the datastore', ->
        expect(@record.root).to.be.true

      it 'should match the generated token', ->
        hashedToken = @sut._hashToken { uuid: 'spiral', token: 'abc123' }
        expect(@record.hashedToken).to.equal hashedToken
