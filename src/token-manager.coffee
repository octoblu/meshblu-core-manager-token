_      = require 'lodash'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
async  = require 'async'

class TokenManager
  constructor: ({@datastore,@cache,@pepper,@uuidAliasResolver}) ->
    throw new Error "Missing mandatory parameter: @pepper" if _.isEmpty @pepper

  generateAndStoreTokenInCache: ({uuid, expireSeconds}, callback) =>
    token = @_generateToken()
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      @hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @_storeHashedTokenInCache {uuid, hashedToken, expireSeconds}, (error) =>
          return callback error if error?
          callback null, token

  generateAndStoreToken: ({uuid, data, metadata}, callback) =>
    metadata ?= data
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      token = @_generateToken()
      @hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @_storeHashedToken {uuid, hashedToken, metadata}, (error) =>
          return callback error if error?
          callback null, token

  hashToken: ({uuid, token}, callback) =>
    return callback null, null unless uuid? and token?
    _.delay =>
      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @pepper
      callback null, hasher.digest 'base64'
    , 0

  checkTokenCache: ({ uuid, token }, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @hashToken { uuid, token }, (error, hashedToken) =>
        return callback error if error?
        @cache.exists "#{uuid}:#{hashedToken}", callback

  removeTokenFromCache: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @hashToken {uuid, token}, (error, hashedToken) =>
        @_clearHashedTokenFromCache {uuid, hashedToken}, callback

  removeHashedTokenFromCache: ({uuid, hashedToken}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_clearHashedTokenFromCache { uuid, hashedToken }, callback

  revokeToken: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @datastore.remove {uuid, hashedToken}, (error) =>
          return callback error if error?
          @_clearHashedTokenFromCache { uuid, hashedToken }, (error) =>
            return callback error if error?
            callback null, true

  revokeTokenByQuery: ({uuid, query}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      theRealQuery = @_getTokenQuery { uuid }
      _.each query, (value, key) =>
        theRealQuery["metadata.#{key}"] = value
      @datastore.find theRealQuery, (error, records) =>
        return callback error if error?
        return callback null, false if _.isEmpty records
        @_clearHashedTokensFromCache records, (error) =>
          return callback error if error?
          @datastore.remove theRealQuery, callback

  verifyToken: ({uuid,token}, callback) =>
    return callback null, false unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @_verifyHashedToken { uuid, token }, callback

  _verifyHashedToken: ({ uuid, token }, callback) =>
    @hashToken { uuid, token }, (error, hashedToken) =>
      @datastore.findOne { uuid, hashedToken }, { uuid: true }, (error, record) =>
        return callback error if error?
        callback null, !!record

  _clearHashedTokensFromCache: (sessionTokens, callback) =>
    async.eachSeries sessionTokens, @_clearHashedTokenFromCache, callback

  _clearHashedTokenFromCache: ({ uuid, hashedToken }, done) =>
    @cache.del "#{uuid}:#{hashedToken}", done

  _generateToken: =>
    return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex')

  _getTokenQuery: ({ uuid }) =>
    return { uuid }

  _storeHashedToken: ({uuid, hashedToken, metadata }, callback) =>
    @_storeHashedTokenInDatastore {uuid, hashedToken, metadata }, (error) =>
      return callback error if error?
      @_storeHashedTokenInCache {uuid, hashedToken}, callback

  _storeHashedTokenInDatastore: ({uuid, hashedToken, metadata}, callback) =>
    record = { uuid, hashedToken }
    record.metadata = metadata if _.isPlainObject metadata
    record.metadata ?= {}
    record.metadata.createdAt = new Date()
    @datastore.insert record, callback

  _storeHashedTokenInCache: ({uuid, hashedToken, expireSeconds}, callback) =>
    if expireSeconds?
      return @cache.setex "#{uuid}:#{hashedToken}", expireSeconds, '', callback
    @cache.set "#{uuid}:#{hashedToken}", '', callback

module.exports = TokenManager
