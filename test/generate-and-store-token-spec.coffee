_         = require 'lodash'
bcrypt    = require 'bcrypt'
crypto    = require 'crypto'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'

TokenManager = require '../src/token-manager'

describe 'TokenManager->generateAndStoreToken', ->
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

  describe 'when called without metadata', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns 'abc123'
      @sut.generateAndStoreToken {uuid: 'spiral'}, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should not add expiresOn to the datastore', ->
        expect(@record.expiresOn).to.not.exist

      it 'should add a token to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should match the generated token', (done) ->
        @sut._hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.hashedToken).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true

  describe 'when called with metadata', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns('abc123')
      metadata =
        tag: 'foo'
      @sut.generateAndStoreToken {uuid: 'spiral', metadata}, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a hashedToken to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should not add expiresOn to the datastore', ->
        expect(@record.expiresOn).to.not.exist

      it 'should match the generated token', (done) ->
        @sut._hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.hashedToken).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(@record.metadata.tag).to.equal 'foo'
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true


  describe 'when called with an expiresOn', ->
    beforeEach (done) ->
      @sut._generateToken = sinon.stub().returns('abc123')
      metadata =
        tag: 'foo'
      @expiresOn = new Date(Date.now() - (1000 * 60))
      @sut.generateAndStoreToken {uuid: 'spiral', metadata, @expiresOn }, (error, @generateToken) =>
        done error

    describe 'when the record is retrieved', ->
      beforeEach (done) ->
        @datastore.findOne { uuid: 'spiral', hashedToken: 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U=' }, (error, @record) =>
          done error

      it 'should add a hashedToken to the datastore', ->
        expect(@record.hashedToken).to.equal 'T/GMBdFNOc9l3uagnYZSwgFfjtp8Vlf6ryltQUEUY1U='

      it 'should add a expiresOn to the datastore', ->
        expect(@record.expiresOn).to.deep.equal @expiresOn

      it 'should match the generated token', (done) ->
        @sut._hashToken { uuid: 'spiral', token: 'abc123' }, (error, hashedToken) =>
          return done error if error?
          expect(@record.hashedToken).to.equal hashedToken
          done()

      it 'should have the correct metadata in the datastore', ->
        expect(@record.metadata.tag).to.equal 'foo'
        expect(new Date(@record.metadata.createdAt).getTime() > (Date.now() - 1000)).to.be.true
