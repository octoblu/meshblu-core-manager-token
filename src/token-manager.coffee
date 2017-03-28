_      = require 'lodash'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@pepper,@uuidAliasResolver}) ->
    throw new Error "Missing mandatory parameter: @pepper" if _.isEmpty @pepper

  generateAndStoreToken: ({ uuid, metadata, expiresOn, root }, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      token = @_generateToken()
      hashedToken = @_hashToken {uuid, token}
      return callback new Error 'Unable to hash token' unless hashedToken?
      @_storeHashedToken { uuid, hashedToken, metadata, expiresOn, root }, (error) =>
        return callback error if error?
        callback null, token

  search: ({uuid, query, projection}, callback) =>
    return callback new Error 'Missing uuid' unless uuid?
    query ?= {}
    projection ?= {}
    secureQuery = _.clone query
    secureQuery.uuid = uuid

    options =
      limit:     1000
      maxTimeMS: 2000
      sort:      {_id: -1}

    @datastore.find secureQuery, projection, options, (error, tokens) =>
      return callback error if error?
      results = _.map tokens, (token) =>
        _.omit token, ['hashedToken']
      callback null, results

  storeToken: ({ uuid, token, expiresOn, root }, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      hashedToken = @_hashToken {uuid, token}
      return callback new Error 'Unable to hash token' unless hashedToken?
      @_storeHashedToken { uuid, hashedToken, expiresOn, root }, callback

  removeRootToken: ({uuid}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @datastore.remove {uuid, root: true}, callback

  revokeToken: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      hashedToken = @_hashToken {uuid, token}
      return callback new Error 'Unable to hash token' unless hashedToken?
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
    return unless uuid? and token?
    hasher = crypto.createHash 'sha256'
    hasher.update token
    hasher.update uuid
    hasher.update @pepper
    hasher.digest 'base64'

  _storeHashedToken: ({ uuid, hashedToken, metadata, expiresOn, root }, callback) =>
    record = { uuid, hashedToken }
    return callback new Error('expires on must be a date') if expiresOn? && !_.isDate(expiresOn)
    record.expiresOn = expiresOn if expiresOn?
    record.root = root if root
    record.metadata = metadata if _.isPlainObject metadata
    record.metadata ?= {}
    record.metadata.createdAt = new Date()
    @datastore.findOne { uuid, hashedToken }, { uuid: true }, (error, found) =>
      return callback error if error?
      return @datastore.insert record, callback unless found?
      @datastore.update { uuid, hashedToken }, { $set: record }, callback

  _verifyHashedToken: ({ uuid, token }, callback) =>
    hashedToken = @_hashToken { uuid, token }
    return callback new Error 'Unable to hash token' unless hashedToken?
    query = { uuid, hashedToken }
    @datastore.findOne query, { uuid: true }, (error, record) =>
      return callback error if error?
      return callback null, false unless record?
      return callback null, true unless record.expiresOn?
      @datastore.remove query, (error) =>
        return callback error if error?
        return callback null, true


module.exports = TokenManager
