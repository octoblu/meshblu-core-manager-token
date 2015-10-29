bcrypt = require 'bcrypt'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@hashToken}) ->

  verifyToken: ({uuid:uuid,token:token}, callback)=>
    @datastore.findOne uuid: uuid, (error, record) =>
      return callback error if error?
      return callback null, false unless record?
      @_verifyRootToken token, record.token, (error,valid)=>
        return callback error if error?
        return callback null, valid if valid
        @_verifySessionToken token, record, callback

  _hashToken: (uuid, token) =>
    hasher = crypto.createHash 'sha256'
    hasher.update uuid
    hasher.update token
    hasher.update @hashToken
    hasher.digest 'base64'

  _verifyRootToken: (token, hashedToken, callback) =>
    bcrypt.compare token, hashedToken, callback

  _verifySessionToken: (token, record, callback) =>
    try
      hashedToken  = @_hashToken record.uuid, token
    catch error
      return callback null, false
    hashedTokens = record.meshblu.tokens

    callback null, hashedTokens[hashedToken]?

module.exports = TokenManager
