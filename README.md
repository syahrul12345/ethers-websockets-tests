# Websocket tests
Fire as many websockets requests as possible

## Setup
Create a .env file (or copy from .example.env) and replace the value for `MAINNET_RPC` and `MAINNET_WS` accordingly.

## Run
To run, you have to choose how many times to loop, and how many requests is done per loop.
```
//Do with 5 iterations, each with 50 websocket requests
cargo run -- --outer 5 --iterations 50
```

or to use an optimized build:
```
make build
./target/release/async-eth --outer 5 --iterations 50
```

## 
Tests
Automatically run test cases which will measure how much time is taken for each test case
```
cargo test -- --nocapture
```
