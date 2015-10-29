bcrypt = require 'bcrypt'

class TokenManager
  constructor: ({@datastore}) ->

  verifyToken: ({uuid:uuid,token:token}, callback)=>
    @datastore.findOne uuid: uuid, (error, record) =>
      return callback error if error?
      return callback null, false unless record?
      bcrypt.compare token, record.token, callback

module.exports = TokenManager
