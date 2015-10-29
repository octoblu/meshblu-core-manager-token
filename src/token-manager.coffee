bcrypt = require 'bcrypt'
crypto = require 'crypto'

class TokenManager
  constructor: ({@datastore,@hashToken}) ->

  verifyToken: ({uuid:uuid,token:token}, callback)=>
    @datastore.findOne uuid: uuid, (error, record) =>
      return callback error if error?
      return callback null, false unless record?
      @verifyRootToken token, record.token, (error,valid)=>
        return callback error if error?
        return callback null, valid if valid
        @verifySessionToken token, record, callback

  verifyRootToken: (token, hashedToken, callback) =>
    bcrypt.compare token, hashedToken, callback

  verifySessionToken: (token, record, callback) =>
    try
      hashedToken  = @_hashToken record.uuid, token
    catch error
      callback error
      return
    hashedTokens = record.meshblu.tokens

    callback null, hashedTokens[hashedToken]?

  _hashToken: (uuid, token) =>
    hasher = crypto.createHash 'sha256'
    hasher.update uuid
    hasher.update token
    hasher.update @hashToken
    hasher.digest 'base64'

module.exports = TokenManager
