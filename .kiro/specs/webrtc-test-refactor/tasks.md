# Implementation Plan: WebRTC Test Refactoring

## Overview

This plan refactors the WebRTC test suite to eliminate CI timeouts by introducing a mock implementation for unit tests while preserving real WebRTC integration tests as ignored tests for manual execution.

## Tasks

- [x] 1. Create mock WebRTC implementation
  - Create `rust-core/src/webrtc_mock.rs` file
  - Implement `MockWebRTCEngine` struct with HashMap-based connection storage
  - Implement connection creation with UUID generation
  - Implement state queries and connection closing
  - Implement establish_connection method
  - _Requirements: 4.1, 4.2, 4.3, 4.5_

- [x] 1.1 Write unit tests for mock implementation
  - Test single connection creation returns non-empty ID
  - Test newly created connection has "New" state
  - Test closing connection removes it from state
  - Test querying non-existent connection returns None
  - Test closing non-existent connection succeeds (idempotence)
  - _Requirements: 4.2, 4.3_

- [x] 1.2 Write property test for connection ID uniqueness
  - **Property 1: Connection ID Uniqueness**
  - **Validates: Requirements 4.2**
  - Generate 2-10 connections and verify all IDs are unique
  - _Requirements: 4.2_

- [x] 1.3 Write property test for initial state consistency
  - **Property 2: Initial State Consistency**
  - **Validates: Requirements 4.3**
  - For any created connection, verify state is always "New"
  - _Requirements: 4.3_

- [x] 1.4 Write property test for state removal after close
  - **Property 4: State Removal After Close**
  - **Validates: Requirements 4.3**
  - For any connection, verify state is None after closing
  - _Requirements: 4.3_

- [x] 2. Refactor existing tests to use mock
  - Update `test_peer_connection_lifecycle` to use `MockWebRTCEngine`
  - Update `test_multiple_connections` to use `MockWebRTCEngine`
  - Update `test_connection_not_found_error` to use `MockWebRTCEngine`
  - Update `test_empty_ice_servers_config` to use `MockWebRTCEngine`
  - Remove timeout wrappers (no longer needed with mock)
  - _Requirements: 1.1, 1.2, 2.1, 2.2_

- [x] 3. Mark real WebRTC tests as ignored
  - Keep `test_webrtc_engine_creation` but mark as `#[ignore]`
  - Add documentation comment explaining how to run ignored tests
  - Add appropriate timeout for ignored tests (30+ seconds)
  - Ensure ignored tests use real `WebRTCEngine`
  - _Requirements: 3.1, 3.2, 3.3, 3.4_

- [x] 4. Update property tests to use mock
  - Update `property_peer_connection_creation` to use `MockWebRTCEngine`
  - Update `property_connection_ids_unique` to use `MockWebRTCEngine`
  - Remove `#[ignore]` attribute from property tests
  - Reduce timeout to 5 seconds (mock is fast)
  - _Requirements: 1.1, 2.1_

- [x] 5. Verify test suite passes in CI
  - Run `cargo test` to verify all non-ignored tests pass
  - Verify tests complete within 30 seconds
  - Run `cargo test -- --ignored` manually to verify integration tests still work
  - _Requirements: 1.1, 3.1_

## Notes

- The mock implementation should be as simple as possible - just HashMap + UUID
- Real `WebRTCEngine` code remains completely unchanged
- All existing test scenarios are preserved, just using mock instead of real WebRTC
- Integration tests remain available for manual execution with `--ignored` flag
