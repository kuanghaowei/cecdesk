# Design Document: WebRTC Test Refactoring

## Overview

This design refactors the WebRTC test suite to eliminate CI timeouts by introducing a trait-based abstraction that allows both real and mock implementations. Unit tests will use a lightweight mock that completes instantly, while integration tests using real WebRTC will be marked as ignored for manual execution only.

## Architecture

### Current Architecture Issues

The current tests directly instantiate `WebRTCEngine::new()`, which:
- Initializes the full WebRTC stack (MediaEngine, InterceptorRegistry, API)
- May attempt network operations even with empty ICE servers
- Can hang indefinitely in resource-constrained CI environments
- Blocks the async runtime waiting for initialization

### Proposed Architecture

```
┌─────────────────────────────────────┐
│      WebRTCEngineInterface          │  (Trait)
│  - create_peer_connection()         │
│  - get_connection_state()           │
│  - close_connection()               │
│  - establish_connection()           │
└─────────────────────────────────────┘
           ▲                  ▲
           │                  │
    ┌──────┴──────┐    ┌─────┴──────┐
    │             │    │            │
┌───┴────────┐  ┌─┴────────────┐
│ WebRTCEngine│  │MockWebRTCEngine│
│  (Real)     │  │   (Test)       │
└─────────────┘  └────────────────┘
```

## Components and Interfaces

### 1. WebRTCEngineInterface Trait

```rust
#[async_trait]
pub trait WebRTCEngineInterface: Send + Sync {
    async fn create_peer_connection(&self, config: RTCConfiguration) -> Result<String>;
    async fn get_connection_state(&self, connection_id: &str) -> Option<RTCPeerConnectionState>;
    async fn close_connection(&self, connection_id: &str) -> Result<()>;
    async fn establish_connection(&self, connection_id: &str, remote_id: String) -> Result<()>;
}
```

### 2. MockWebRTCEngine Implementation

A test-only implementation that:
- Stores connection state in a simple HashMap
- Generates UUIDs for connection IDs
- Returns states immediately without async delays
- Never performs network operations
- Simulates state transitions deterministically

```rust
pub struct MockWebRTCEngine {
    connections: Arc<Mutex<HashMap<String, MockConnectionInfo>>>,
}

struct MockConnectionInfo {
    id: String,
    state: RTCPeerConnectionState,
    remote_id: Option<String>,
}
```

### 3. Test Organization

**Unit Tests (Not Ignored)**
- Use `MockWebRTCEngine`
- Test business logic: ID generation, state management, error handling
- Complete in milliseconds
- Run in CI

**Integration Tests (Ignored)**
- Use real `WebRTCEngine`
- Test actual WebRTC behavior
- Marked with `#[ignore]`
- Run manually with `cargo test -- --ignored`

## Data Models

### RTCConfiguration
```rust
pub struct RTCConfiguration {
    pub ice_servers: Vec<IceServer>,
    pub ice_transport_policy: String,
    pub bundle_policy: Option<String>,
    pub rtcp_mux_policy: Option<String>,
}
```

### MockConnectionInfo
```rust
struct MockConnectionInfo {
    id: String,
    state: RTCPeerConnectionState,
    remote_id: Option<String>,
    created_at: Instant,
}
```

## Correctness Properties

*A property is a characteristic or behavior that should hold true across all valid executions of a system—essentially, a formal statement about what the system should do. Properties serve as the bridge between human-readable specifications and machine-verifiable correctness guarantees.*


### Property 1: Connection ID Uniqueness

*For any* number of connection creations (n >= 2), all generated connection IDs should be unique.

**Validates: Requirements 4.2**

### Property 2: Initial State Consistency

*For any* newly created connection, querying its state immediately after creation should always return `RTCPeerConnectionState::New`.

**Validates: Requirements 4.3**

### Property 3: Connection Lifecycle Idempotence

*For any* connection ID, closing a connection that doesn't exist should succeed without error (idempotent operation).

**Validates: Requirements 4.3**

### Property 4: State Removal After Close

*For any* connection, after closing it, querying its state should return `None`.

**Validates: Requirements 4.3**

## Error Handling

### Mock Error Scenarios

1. **Non-existent Connection**: Operations on non-existent connections should either:
   - Return `None` for queries (get_connection_state)
   - Return `Ok(())` for idempotent operations (close_connection)
   - Return `Err` for operations requiring existing connection (establish_connection)

2. **Invalid Configuration**: Mock should accept any configuration without validation (validation is WebRTC's responsibility)

### Real WebRTC Error Scenarios

Real WebRTC tests (ignored) will continue to test:
- Network timeouts
- ICE gathering failures
- SDP negotiation errors

## Testing Strategy

### Unit Testing with Mocks

**Test Framework**: Standard Rust `#[tokio::test]` with `MockWebRTCEngine`

**Test Categories**:
1. **Connection Creation Tests**
   - Single connection creation
   - Multiple connection creation (ID uniqueness)
   - Connection state verification

2. **Connection Lifecycle Tests**
   - Create → Query State → Close → Verify Removed
   - Close non-existent connection (idempotence)

3. **Error Handling Tests**
   - Query non-existent connection
   - Establish connection with non-existent ID

**Property-Based Tests**: Use `proptest` with mock implementation
- Minimum 100 iterations per property
- Test with varying numbers of connections (1-10)
- Verify uniqueness across all generated IDs

### Integration Testing with Real WebRTC

**Test Framework**: `#[tokio::test]` with `#[ignore]` attribute

**Test Categories**:
1. **Real WebRTC Initialization** (ignored)
2. **Actual Peer Connection** (ignored, requires network)
3. **ICE Gathering** (ignored, requires STUN server)

**Execution**: `cargo test -- --ignored`

### Test Organization

```
rust-core/src/
├── webrtc_engine.rs          # Real implementation
├── webrtc_engine_test.rs     # Integration tests (ignored)
└── webrtc_mock.rs            # Mock implementation + unit tests
```

### Property Test Tags

Each property test must include a comment:
```rust
// Feature: webrtc-test-refactor, Property 1: Connection ID Uniqueness
```

## Implementation Notes

### Minimal Changes to Existing Code

The real `WebRTCEngine` implementation remains unchanged. We only:
1. Extract a trait interface
2. Implement the trait for `WebRTCEngine`
3. Create `MockWebRTCEngine` implementing the same trait
4. Refactor tests to use the trait

### Mock Implementation Strategy

The mock should be as simple as possible:
- Use `HashMap` for connection storage
- Use `uuid::Uuid` for ID generation (same as real implementation)
- No async delays or sleeps
- No network operations
- Deterministic state transitions

### Backward Compatibility

Existing code using `WebRTCEngine` directly is unaffected. The trait is only used in tests.
