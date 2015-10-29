bcrypt = require 'bcrypt'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@pepper}) ->

  hashToken: (uuid, token) =>
    hasher = crypto.createHash 'sha256'
    hasher.update uuid
    hasher.update token
    hasher.update @pepper
    hasher.digest 'base64'

  verifyToken: ({uuid:uuid,token:token}, callback) =>
    @datastore.findOne uuid: uuid, (error, record) =>
      return callback error if error?
      return callback null, false unless record?

      @_verifySessionToken token, record, (error,valid) =>
        return callback error if error?
        return callback null, valid if valid

        @_verifyRootToken token, record.token, callback

  _verifyRootToken: (token, hashedToken, callback) =>
    bcrypt.compare token, hashedToken, callback

  _verifySessionToken: (token, record, callback) =>
    try
      hashedToken  = @hashToken record.uuid, token
    catch error
      return callback null, false
    hashedTokens = record.meshblu.tokens

    callback null, hashedTokens[hashedToken]?

module.exports = TokenManager
