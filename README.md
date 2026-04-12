# sindarin-pkg-net-quic

QUIC transport for the [Sindarin](https://github.com/SindarinSDK/sindarin-compiler) programming language, backed by [ngtcp2](https://github.com/ngtcp2/ngtcp2) with OpenSSL. Provides multiplexed bidirectional and unidirectional streams over encrypted UDP with low-latency connection establishment, configurable flow control, 0-RTT early data, and connection migration.

## Installation

Add the package as a dependency in your `sn.yaml`:

```yaml
dependencies:
- name: sindarin-pkg-net-quic
  git: git@github.com:SindarinSDK/sindarin-pkg-net-quic.git
  branch: main
```

Then run `sn --install` to fetch the package.

## Quick Start

```sindarin
import "sindarin-pkg-net-quic/src/quic"

fn main(): void =>
    # Server
    var server: QuicListener = QuicListener.bind(":4433", "cert.pem", "key.pem")
    var serverConn: QuicConnection = server.accept()
    var serverStream: QuicStream = serverConn.acceptStream()
    var msg: str = serverStream.readLine()
    serverStream.writeLine($"Echo: {msg}")
    serverStream.close()
    serverConn.close()
    server.close()
```

```sindarin
import "sindarin-pkg-net-quic/src/quic"

fn main(): void =>
    # Client
    var conn: QuicConnection = QuicConnection.connect("server:4433")
    var stream: QuicStream = conn.openStream()
    stream.writeLine("Hello, QUIC!")
    var response: str = stream.readLine()
    print(response)
    stream.close()
    conn.close()
```

---

## QuicListener

```sindarin
import "sindarin-pkg-net-quic/src/quic"
```

A QUIC server that listens for incoming connections. Requires TLS certificate and key PEM files. Clients load CA certificates from the `SN_CERTS` environment variable or the platform certificate store.

| Method | Signature | Description |
|--------|-----------|-------------|
| `bind` | `static fn bind(address: str, certFile: str, keyFile: str): QuicListener` | Bind a listener to an address (e.g. `":4433"` or `":0"` for ephemeral port) |
| `bindWith` | `static fn bindWith(address: str, certFile: str, keyFile: str, config: QuicConfig): QuicListener` | Bind with custom configuration |
| `accept` | `fn accept(): QuicConnection` | Block until a client connects and return the connection |
| `port` | `fn port(): int` | Get the bound port number |
| `close` | `fn close(): void` | Close the listener and wake any parked `accept()` calls |
| `dispose` | `fn dispose(): void` | Release listener resources |

```sindarin
var server: QuicListener = QuicListener.bind(":0", "cert.pem", "key.pem")
print($"Listening on port {server.port()}\n")

var conn: QuicConnection = server.accept()
# handle connection ...
conn.close()
server.close()
```

---

## QuicConnection

A QUIC connection supporting multiplexed streams. Each connection runs its own I/O thread for packet processing and timers.

| Method | Signature | Description |
|--------|-----------|-------------|
| `connect` | `static fn connect(address: str): QuicConnection` | Connect to a QUIC server (`host:port`) |
| `connectWith` | `static fn connectWith(address: str, config: QuicConfig): QuicConnection` | Connect with custom configuration |
| `connectEarly` | `static fn connectEarly(address: str, token: byte[]): QuicConnection` | Connect with 0-RTT early data using a saved resumption token |
| `openStream` | `fn openStream(): QuicStream` | Open a new bidirectional stream |
| `openUnidirectionalStream` | `fn openUnidirectionalStream(): QuicStream` | Open a new unidirectional stream (write-only from this side) |
| `acceptStream` | `fn acceptStream(): QuicStream` | Block until the peer opens a stream |
| `serve` | `fn serve(handler: fn(QuicStream): int): void` | Accept streams in a loop, spawning a thread per stream |
| `resumptionToken` | `fn resumptionToken(): byte[]` | Get a token for 0-RTT reconnection |
| `migrate` | `fn migrate(newLocalAddress: str): void` | Migrate the connection to a new local address |
| `isClosed` | `fn isClosed(): bool` | Check if the connection is closed |
| `remoteAddress` | `fn remoteAddress(): str` | Get the remote peer address |
| `close` | `fn close(): void` | Gracefully close the connection |
| `dispose` | `fn dispose(): void` | Release connection resources |

```sindarin
var conn: QuicConnection = QuicConnection.connect("127.0.0.1:4433")

var s1: QuicStream = conn.openStream()
s1.writeLine("hello")
var reply: str = s1.readLine()
s1.close()

conn.close()
```

---

## QuicStream

A QUIC stream for bidirectional or unidirectional communication. Streams are multiplexed over a single connection without head-of-line blocking.

| Method | Signature | Description |
|--------|-----------|-------------|
| `read` | `fn read(maxBytes: int): byte[]` | Read up to `maxBytes` (may return fewer) |
| `readExact` | `fn readExact(n: int): byte[]` | Read exactly `n` bytes, blocking until all arrive or stream closes |
| `readAll` | `fn readAll(): byte[]` | Read until the peer closes the stream |
| `readLine` | `fn readLine(): str` | Read until newline |
| `write` | `fn write(data: byte[]): int` | Write bytes, return count written |
| `writeLine` | `fn writeLine(text: str): void` | Write a string followed by a newline |
| `id` | `fn id(): long` | Get the stream ID |
| `isUnidirectional` | `fn isUnidirectional(): bool` | True if this is a unidirectional stream |
| `isClosed` | `fn isClosed(): bool` | True if the stream is closed |
| `close` | `fn close(): void` | Close the stream (sends FIN) |
| `dispose` | `fn dispose(): void` | Release stream resources |

```sindarin
var stream: QuicStream = conn.openStream()

# Line-oriented protocol
stream.writeLine("GET /status")
var status: str = stream.readLine()

# Binary protocol
var data: byte[] = "binary payload".toBytes()
stream.write(data)
var response: byte[] = stream.readExact(128)

stream.close()
```

---

## QuicConfig

Configuration for connections and listeners. All builder methods return `self` for chaining.

| Method | Signature | Description |
|--------|-----------|-------------|
| `defaults` | `static fn defaults(): QuicConfig` | Create a config with sensible defaults |
| `setMaxBidiStreams` | `fn setMaxBidiStreams(n: int): QuicConfig` | Maximum concurrent bidirectional streams (default: 100) |
| `setMaxUniStreams` | `fn setMaxUniStreams(n: int): QuicConfig` | Maximum concurrent unidirectional streams |
| `setMaxStreamWindow` | `fn setMaxStreamWindow(bytes: int): QuicConfig` | Per-stream flow control window in bytes |
| `setMaxConnWindow` | `fn setMaxConnWindow(bytes: int): QuicConfig` | Per-connection flow control window in bytes |
| `setIdleTimeout` | `fn setIdleTimeout(ms: int): QuicConfig` | Idle timeout in milliseconds (0 = no timeout) |

```sindarin
var config: QuicConfig = QuicConfig.defaults()
    .setMaxBidiStreams(50)
    .setIdleTimeout(5000)
    .setMaxStreamWindow(131072)

var server: QuicListener = QuicListener.bindWith(":4433", "cert.pem", "key.pem", config)
var client: QuicConnection = QuicConnection.connectWith("server:4433", config)
```

---

## Examples

### Echo server

```sindarin
import "sindarin-pkg-net-quic/src/quic"

fn handleStream(stream: QuicStream): int =>
    while !stream.isClosed() =>
        var msg: str = stream.readLine()
        if msg == "" =>
            return 0
        stream.writeLine($"echo: {msg}")
    return 0

fn main(): void =>
    var server: QuicListener = QuicListener.bind(":4433", "cert.pem", "key.pem")
    print($"Listening on :{server.port()}\n")

    var conn: QuicConnection = server.accept()
    conn.serve(handleStream)

    conn.close()
    server.close()
```

### Multiple streams on one connection

```sindarin
import "sindarin-pkg-net-quic/src/quic"

fn main(): void =>
    var conn: QuicConnection = QuicConnection.connect("server:4433")

    var s1: QuicStream = conn.openStream()
    var s2: QuicStream = conn.openStream()

    s1.writeLine("request on stream 1")
    s2.writeLine("request on stream 2")

    print(s1.readLine())
    print(s2.readLine())

    s1.close()
    s2.close()
    conn.close()
```

### 0-RTT reconnection

```sindarin
import "sindarin-pkg-net-quic/src/quic"

fn main(): void =>
    # First connection — save the resumption token
    var conn: QuicConnection = QuicConnection.connect("server:4433")
    var token: byte[] = conn.resumptionToken()
    conn.close()

    # Second connection — use the token for 0-RTT early data
    var fast: QuicConnection = QuicConnection.connectEarly("server:4433", token)
    var stream: QuicStream = fast.openStream()
    stream.writeLine("fast reconnect!")
    stream.close()
    fast.close()
```

### Custom idle timeout with retry

```sindarin
import "sindarin-pkg-net-quic/src/quic"
import "sindarin-pkg-sdk/src/time/time"

fn main(): void =>
    var config: QuicConfig = QuicConfig.defaults().setIdleTimeout(1000)
    var connected: bool = false

    while !connected =>
        var conn: QuicConnection = QuicConnection.connectWith("server:4433", config)
        if conn.isClosed() =>
            print("Server not ready, retrying...\n")
            Time.sleep(500)
        else =>
            var stream: QuicStream = conn.openStream()
            stream.writeLine("hello")
            print(stream.readLine())
            stream.close()
            conn.close()
            connected = true
```

---

## Development

```bash
# Install native libraries (downloads prebuilt ngtcp2 + OpenSSL from GitHub Releases)
make install-libs

# Install Sindarin dependencies
sn --install

# Run all tests
make test

# Remove build artifacts
make clean
```

Tests are self-contained — they start local listeners on ephemeral ports and require no external services.

## Dependencies

- [sindarin-pkg-sdk](https://github.com/SindarinSDK/sindarin-pkg-sdk) — Sindarin standard library (provides Time, TCP for resilience tests).
- [ngtcp2](https://github.com/ngtcp2/ngtcp2) v1.21.0 — QUIC protocol implementation (statically linked, built via vcpkg).
- [OpenSSL](https://www.openssl.org/) — TLS 1.3 crypto backend for ngtcp2 (statically linked).

## License

MIT License
