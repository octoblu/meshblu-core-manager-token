# meshblu-core-manager-token
Meshblu Token Manager

[![Build Status](https://travis-ci.org/octoblu/meshblu-core-manager-token.svg?branch=master)](https://travis-ci.org/octoblu/meshblu-core-manager-token)
[![Test Coverage](https://codecov.io/gh/octoblu/meshblu-core-manager-token/branch/master/graph/badge.svg)](https://codecov.io/gh/octoblu/meshblu-core-manager-token)
[![Dependency status](http://img.shields.io/david/octoblu/meshblu-core-manager-token.svg?style=flat)](https://david-dm.org/octoblu/meshblu-core-manager-token)
[![devDependency Status](http://img.shields.io/david/dev/octoblu/meshblu-core-manager-token.svg?style=flat)](https://david-dm.org/octoblu/meshblu-core-manager-token#info=devDependencies)
[![Slack Status](http://community-slack.octoblu.com/badge.svg)](http://community-slack.octoblu.com)

[![NPM](https://nodei.co/npm/meshblu-core-manager-token.svg?style=flat)](https://npmjs.org/package/meshblu-core-manager-token)



## Tokens Datastore Format

```coffee
tokens = [
  # Normal session token record
  {
    uuid: 'some-uuid'
    hashedToken: 'hashed-token'
    metadata:
      createdAt: new Date()
  }
  # Session token record with custom tags
  {
    uuid: 'some-uuid'
    hashedToken: 'hashed-token'
    metadata:
      tag: 'some-custom-tag'
      random: 'property'
      createdAt: new Date()
  }
]
```


## Tokens collection indexes

uuid, hashedToken, expiresOn
