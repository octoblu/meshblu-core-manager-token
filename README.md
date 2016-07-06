# meshblu-core-manager-token
Meshblu Token Manager

[![Build Status](https://travis-ci.org/octoblu/meshblu-core-manager-token.svg?branch=master)](https://travis-ci.org/octoblu/meshblu-core-manager-token)
[![Code Climate](https://codeclimate.com/github/octoblu/meshblu-core-manager-token/badges/gpa.svg)](https://codeclimate.com/github/octoblu/meshblu-core-manager-token)
[![Test Coverage](https://codeclimate.com/github/octoblu/meshblu-core-manager-token/badges/coverage.svg)](https://codeclimate.com/github/octoblu/meshblu-core-manager-token)
[![npm version](https://badge.fury.io/js/meshblu-core-manager-token.svg)](http://badge.fury.io/js/meshblu-core-manager-token)
[![Gitter](https://badges.gitter.im/octoblu/help.svg)](https://gitter.im/octoblu/help)


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
