_      = require 'lodash'
bcrypt = require 'bcrypt'
crypto = require 'crypto'
async  = require 'async'

class TokenManager
  constructor: ({@datastore,@cache,@pepper,@uuidAliasResolver}) ->

  hashToken: (uuid, token, callback) =>
    return callback null, null unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @pepper
      callback null, hasher.digest 'base64'

  revokeTokenByQuery: (uuid, query, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      @datastore.findOne {uuid}, (error, record) =>
        return callback error if error?
        return callback null, false unless record?

        hashedTokens = _.pick record.meshblu.tokens, (value) => _.some [value], query
        hashedTokenKeys = _.keys hashedTokens
        unsetHashTokens = _.mapKeys hashedTokens, (_, hashedToken) => "meshblu.tokens.#{hashedToken}"
        unsetHashTokens = _.mapValues unsetHashTokens, => true

        return callback null unless _.size hashedTokenKeys
        @_clearTokensFromCache uuid, hashedTokenKeys, =>
          @datastore.update {uuid}, $unset: unsetHashTokens, callback

  verifyToken: ({uuid,token}, callback) =>
    return callback null, false unless uuid? and token?
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      @datastore.findOne {uuid}, (error, record) =>
        return callback error if error?
        return callback null, false unless record?

        @_verifySessionToken token, record, (error,valid) =>
          return callback error if error?
          return callback null, valid if valid

          @_verifyRootToken token, record.token, callback

  _clearTokensFromCache: (uuid, hashedTokens, callback) =>
    async.each hashedTokens, async.apply(@_clearTokenFromCache, uuid), callback

  _clearTokenFromCache: (uuid, hashedToken, done) =>
    @cache.del "#{uuid}:#{hashedToken}", done

  _verifyRootToken: (token, hashedToken, callback) =>
    return callback null, false unless token? and hashedToken?
    bcrypt.compare token, hashedToken, callback

  _verifySessionToken: (token, record, callback) =>
    return callback null, false unless token? and record.meshblu?.tokens?
    @hashToken record.uuid, token, (error, hashedToken) =>
      return callback error if error?
      return callback null, false unless hashedToken?
      hashedTokens = record.meshblu.tokens
      callback null, hashedTokens[hashedToken]?

module.exports = TokenManager
