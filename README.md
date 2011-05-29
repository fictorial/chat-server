# chat-server ![Project Status](http://stillmaintained.com/fictorial/chat-server.png)

A multi-user chat server, client module, and sample client CLI.

## Installation

    npm i chat-server

## Running

    chat-server [OPTIONS]

    Options:
    -h ip     ip to bind to              default: 127.0.0.1
    -p port   port to bind to            default: 11746
    -m bytes  max input size per client  default: 1MB
    -l level  log level                  default: error

## Client Usage

client-al.js

````javascript
var client = require('chat-server').connect();
client.nick('Al');
client.join('jokes');
client.say('jokes', 'what did the hat say to the hat rack?');
````

client-bob.js

````javascript
var client = require('chat-server').connect();
client.nick('Bob');
client.join('jokes');
client.on('say', function (channel, who, message) {
  console.log(new Date(), channel, who, message);
});
````

## Client API

### var client = require('chat-server').connect(port, host)

Connect to a running chat server on host:port.

### client methods

#### nick('nickname')

Set the client's nickname. Must be the first call made.

#### join('channel')

Join a channel.

#### part('channel', 'why')

Leave/part a channel.

#### list(callback)

List all active channels.

#### members('channel', callback)

List all members of a channel. 'callback' is passed an array of
nicknames.

#### say('channel', 'what')

Say something in a channel. Must already have joined the channel.

### client events

#### 'client-error' (error)

Client I/O error talking to server (e.g. ECONNREFUSED).

#### 'server-error' (message)

Something you tried to do did not go so well (e.g. nickname already in use).

#### 'protocol-error' (error, line)

Shouldn't happen. The server sent a malformed protocol message.

#### 'join' (channel, who)

Someone joined a channel we joined.

#### 'part' (channel, who, why)

Someone parted a channel we joined.

#### 'say' (channel, who, what)

Someone said something in a channel we joined.

#### 'nick' (channel, old_nick, new_nick)

Someone changed their nickname in a channel we joined.

## Protocol

The client/server protocol is based on CRLF-delimited JSON objects.

### Client Requests

     { "nick": "unique-nickname" }
     { "list": "channel-prefix"  }
     { "join": "channel-name" }
     { "members": "channel-name" }
     { "say": "channel-name", "what": "message" }
     { "part": "channel-name", "why": "reason"  }
     { "info": true }

### Server Responses

A subset of client requests elicit a response.

     { "error": "error-message" }
     { "list": ["channel-name", ...] }
     { "members": "channel-name", "nicks": ["nick", ...] }
     { "info": { "channels": int, "users": int, "uptime": int } }

### Server Notifications

Something happened server-side that the client might be interested in.

     { "join": "channel-name", "who": "nick" }
     { "part": "channel-name", "who": "nick", "why":  "reason"   }
     { "say":  "channel-name", "who": "nick", "what": "message"  }
     { "nick": "channel-name", "old_nick": "nick", "new_nick": "new-nick" }

## Notes

Any client wrongdoing results in an immediate disconnection.

This server does not connect to other servers like a IRC network.

## Author

Brian Hammond <brian@fictorial.com> (http://fictorial.com)

## License

Copyright (c) 2011 Fictorial LLC.

Permission is hereby granted, free of charge, to any person obtaining a copy of
this software and associated documentation files (the "Software"), to deal in
the Software without restriction, including without limitation the rights to
use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies
of the Software, and to permit persons to whom the Software is furnished to do
so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
