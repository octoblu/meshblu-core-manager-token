_      = require 'lodash'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
async  = require 'async'

class TokenManager
  constructor: ({@datastore,@cache,@pepper,@uuidAliasResolver}) ->
    throw new Error "Missing mandatory parameter: @pepper" if _.isEmpty @pepper

  generateToken: =>
    return crypto.createHash('sha1').update((new Date()).valueOf().toString() + Math.random().toString()).digest('hex');

  generateAndStoreTokenInCache: ({uuid, expireSeconds}, callback) =>
    token = @generateToken()
    @hashToken {uuid, token}, (error, hashedToken) =>
      return callback error if error?

      @_storeHashedTokenInCache {uuid, hashedToken, expireSeconds}, (error) =>
        return callback error if error?
        callback null, token

  generateAndStoreToken: ({uuid, data}, callback) =>
    token = @generateToken()
    @hashToken {uuid, token}, (error, hashedToken) =>
      return callback error if error?
      @_storeHashedToken {uuid, token: hashedToken, metadata: data}, (error) =>
        return callback error if error?
        @_storeHashedTokenInCache {uuid, hashedToken}, (error) =>
          return callback error if error?
          callback null, token

  hashToken: ({uuid, token}, callback) =>
    return callback null, null unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @pepper
      callback null, hasher.digest 'base64'

  removeTokenFromCache: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      @hashToken {uuid, token}, (error, hashedToken) =>
        @_clearHashedTokenFromCache uuid, hashedToken, callback

  removeHashedTokenFromCache: ({uuid, hashedToken}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?

      @_clearHashedTokenFromCache uuid, hashedToken, callback

  revokeToken: ({uuid, token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @hashToken {uuid, token}, (error, hashedToken) =>
        return callback error if error?
        @datastore.remove {uuid, token: hashedToken}, (error) =>
          return callback error if error?
          @_clearHashedTokenFromCache uuid, hashedToken, (error) =>
            return callback error if error?
            callback null, true

  revokeTokenByQuery: ({uuid, query}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      theRealQuery = {uuid, root: false}
      _.each query, (value, key) =>
        theRealQuery["metadata.#{key}"] = value
      @datastore.find theRealQuery, (error, records) =>
        return callback error if error?
        return callback null, false if _.isEmpty records
        tokens = _.map records, 'token'
        @_clearHashedTokensFromCache uuid, tokens, (error) =>
          return callback error if error?
          @datastore.remove theRealQuery, callback

  verifyToken: ({uuid,token}, callback) =>
    return callback null, false unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      return callback error if error?
      @datastore.find {uuid}, (error, records) =>
        return callback error if error?
        return callback null, false if _.isEmpty records
        sessionTokens = _.filter records, { root: false }
        hashedTokens = _.map sessionTokens, 'token'
        @_verifySessionToken { uuid, token, hashedTokens }, (error, valid) =>
          return callback error if error?
          return callback null, valid if valid
          rootTokenRecord = _.find records, { root: true }
          return callback null, false unless rootTokenRecord?
          @_verifyRootToken token, rootTokenRecord.token, callback

  _clearHashedTokensFromCache: (uuid, hashedTokens, callback) =>
    clearCache = async.apply @_clearHashedTokenFromCache, uuid
    async.eachSeries hashedTokens, clearCache, callback

  _clearHashedTokenFromCache: (uuid, hashedToken, done) =>
    @cache.del "#{uuid}:#{hashedToken}", done

  _storeHashedToken: ({uuid, token, metadata}, callback) =>
    record = { uuid, token, root: false }
    record.metadata = metadata if _.isPlainObject metadata
    record.metadata ?= {}
    record.metadata.createdAt = new Date()
    @datastore.insert record, callback

  _storeHashedTokenInCache: ({uuid, hashedToken, expireSeconds}, callback) =>
    if expireSeconds?
      return @cache.setex "#{uuid}:#{hashedToken}", expireSeconds, '', callback

    @cache.set "#{uuid}:#{hashedToken}", '', callback

  _verifyRootToken: (token, hashedToken, callback) =>
    return callback null, false unless token? and hashedToken?
    bcrypt.compare token, hashedToken, callback

  _verifySessionToken: ({ uuid, token, hashedTokens }, callback) =>
    return callback null, false unless token?
    return callback null, false if _.isEmpty hashedTokens
    @hashToken {uuid, token}, (error, hashedToken) =>
      return callback error if error?
      return callback null, false unless hashedToken?
      callback null, hashedToken in hashedTokens

module.exports = TokenManager
