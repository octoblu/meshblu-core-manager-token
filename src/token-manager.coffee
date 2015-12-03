bcrypt = require 'bcrypt'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@pepper,@uuidAliasResolver}) ->

  hashToken: (uuid, token, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      hasher = crypto.createHash 'sha256'
      hasher.update token
      hasher.update uuid
      hasher.update @pepper
      callback null, hasher.digest 'base64'

  verifyToken: ({uuid,token}, callback) =>
    @uuidAliasResolver.resolve uuid, (error, uuid) =>
      @datastore.findOne {uuid}, (error, record) =>
        return callback error if error?
        return callback null, false unless record?

        @_verifySessionToken token, record, (error,valid) =>
          return callback error if error?
          return callback null, valid if valid

          @_verifyRootToken token, record.token, callback

  _verifyRootToken: (token, hashedToken, callback) =>
    bcrypt.compare token, hashedToken, callback

  _verifySessionToken: (token, record, callback) =>
    return callback null, false unless record.meshblu?.tokens?

    @hashToken record.uuid, token, (error, hashedToken) =>
      return callback error if error?

      hashedTokens = record.meshblu.tokens
      callback null, hashedTokens[hashedToken]?

module.exports = TokenManager
