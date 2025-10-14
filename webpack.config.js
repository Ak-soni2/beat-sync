const path = require('path');

module.exports = [
  {
    name: 'sfu-broadcast',
    mode: 'development',
    target: 'web',
    entry: './src/sfu-broadcast-entry.js',
    output: {
      path: path.resolve(__dirname, 'public/dist'),
      filename: 'sfu-broadcast.bundle.js',
      library: {
        type: 'var',
        name: 'SFUBroadcast'
      }
    },
    resolve: {
      fallback: {
        "buffer": false,
        "crypto": false,
        "events": require.resolve("events/"),
        "stream": false,
        "util": false
      }
    }
  },
  {
    name: 'sfu-listen',
    mode: 'development', 
    target: 'web',
    entry: './src/sfu-listen-entry.js',
    output: {
      path: path.resolve(__dirname, 'public/dist'),
      filename: 'sfu-listen.bundle.js',
      library: {
        type: 'var',
        name: 'SFUListen'
      }
    },
    resolve: {
      fallback: {
        "buffer": false,
        "crypto": false,
        "events": require.resolve("events/"),
        "stream": false,
        "util": false
      }
    }
  }
];
