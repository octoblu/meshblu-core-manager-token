_      = require 'lodash'
bcrypt = require 'bcrypt'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@pepper,@uuidAliasResolver}) ->
    throw new Error "Missing mandatory parameter: @pepper" if _.isEmpty @pepper

  generateAndStoreToken: ({ uuid, metadata, expiresOn }, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      token = @_generateToken()
      @_hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @_storeHashedToken { uuid, hashedToken, metadata, expiresOn }, (error) =>
          return callback error if error?
          callback null, token

  storeToken: ({ uuid, token, expiresOn }, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      @_hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @_storeHashedToken { uuid, hashedToken, expiresOn }, (error) =>
          return callback error if error?
          callback null

  revokeToken: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @datastore.remove { uuid, hashedToken }, (error) =>
          return callback error if error?
          callback null, true

  revokeTokenByQuery: ({uuid, query}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      removeQuery = { uuid }
      _.each query, (value, key) =>
        removeQuery["metadata.#{key}"] = value
      @datastore.remove removeQuery, (error) =>
        return callback error if error?
        callback null, true

  verifyToken: ({ uuid, token }, callback) =>
    return callback null, false unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_verifyHashedToken { uuid, token }, callback

  _generateToken: =>
    return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex')

  _hashToken: ({uuid, token}, callback) =>
    return callback() unless uuid? and token?
    _.delay =>
      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @pepper
      callback null, hasher.digest 'base64'
    , 0

  _storeHashedToken: ({ uuid, hashedToken, metadata, expiresOn }, callback) =>
    record = { uuid, hashedToken }
    return callback new Error('expires on must be a date') if expiresOn? && !_.isDate(expiresOn)
    record.expiresOn = expiresOn if expiresOn?
    record.metadata = metadata if _.isPlainObject metadata
    record.metadata ?= {}
    record.metadata.createdAt = new Date()
    @datastore.insert record, callback

  _verifyHashedToken: ({ uuid, token }, callback) =>
    @_hashToken { uuid, token }, (error, hashedToken) =>
      query = { uuid, hashedToken }
      query.$or = [
        {
          expiresOn: { $exists: true, $gte: new Date() }
        },
        {
          expiresOn: { $exists: false }
        }
      ]
      @datastore.findOne query, { uuid: true }, (error, record) =>
        return callback error if error?
        callback null, !!record

module.exports = TokenManager
