_         = require 'lodash'
mongojs   = require 'mongojs'
Datastore = require 'meshblu-core-datastore'
TokenManager = require '../'

describe 'TokenManager->removeRootToken', ->
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


  describe 'when there is a root token', ->
    beforeEach (done) ->
      @datastore.insert {uuid: 'spiral', root: true}, done

    beforeEach (done) ->
      @sut.removeRootToken {uuid: 'spiral'}, (error) =>
        done error

    it 'should not exist in the database', (done) ->
      @datastore.findOne {uuid: 'spiral', root: true}, (error, record) =>
        return done error if error?
        expect(record).to.not.exist
        done()

  describe 'when there are multiple root tokens', ->
    beforeEach (done) ->
      @datastore.insert [{uuid: 'spiral', root: true}, {uuid: 'spiral', root: true}], done

    beforeEach (done) ->
      @sut.removeRootToken {uuid: 'spiral'}, (error) =>
        done error

    it 'should not exist in the database', (done) ->
      @datastore.findOne {uuid: 'spiral', root: true}, (error, record) =>
        return done error if error?
        expect(record).to.not.exist
        done()

  describe 'when there is no root token', ->
    beforeEach (done) ->
      @sut.removeRootToken {uuid: 'spiral'}, (@error) => done()

    it 'should not error', ->
      expect(@error).to.not.exist
