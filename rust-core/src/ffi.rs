// FFI bindings for cross-language interoperability
use crate::*;
use std::ffi::{CStr, CString};
use std::os::raw::{c_char, c_int, c_void};

// C-compatible error codes
pub const FFI_SUCCESS: c_int = 0;
pub const FFI_ERROR_INVALID_PARAM: c_int = -1;
pub const FFI_ERROR_NOT_INITIALIZED: c_int = -2;
pub const FFI_ERROR_CONNECTION_FAILED: c_int = -3;
pub const FFI_ERROR_UNKNOWN: c_int = -99;

// Opaque handles for Rust objects
pub type WebRTCEngineHandle = *mut c_void;
pub type SignalingClientHandle = *mut c_void;
pub type SessionManagerHandle = *mut c_void;

// C-compatible structures
#[repr(C)]
pub struct CDeviceInfo {
    pub device_id: *const c_char,
    pub device_name: *const c_char,
    pub platform: *const c_char,
    pub version: *const c_char,
}

#[repr(C)]
pub struct CNetworkStats {
    pub rtt: u32,
    pub packet_loss: f32,
    pub jitter: u32,
    pub bandwidth: u64,
    pub connection_type: c_int, // 0=Direct, 1=Relay, 2=Unknown
}

// WebRTC Engine FFI functions
#[no_mangle]
pub extern "C" fn webrtc_engine_create() -> WebRTCEngineHandle {
    match WebRTCEngine::new() {
        Ok(engine) => Box::into_raw(Box::new(engine)) as WebRTCEngineHandle,
        Err(_) => std::ptr::null_mut(),
    }
}

#[no_mangle]
pub extern "C" fn webrtc_engine_destroy(handle: WebRTCEngineHandle) {
    if !handle.is_null() {
        unsafe {
            let _ = Box::from_raw(handle as *mut WebRTCEngine);
        }
    }
}

#[no_mangle]
pub extern "C" fn webrtc_engine_create_peer_connection(
    handle: WebRTCEngineHandle,
    config_json: *const c_char,
    connection_id_out: *mut *mut c_char,
) -> c_int {
    if handle.is_null() || config_json.is_null() || connection_id_out.is_null() {
        return FFI_ERROR_INVALID_PARAM;
    }

    unsafe {
        let engine = &mut *(handle as *mut WebRTCEngine);
        let config_str = match CStr::from_ptr(config_json).to_str() {
            Ok(s) => s,
            Err(_) => return FFI_ERROR_INVALID_PARAM,
        };

        // Parse JSON config (placeholder)
        let config = RTCConfiguration {
            ice_servers: vec![],
            ice_transport_policy: "all".to_string(),
        };

        match tokio::runtime::Runtime::new().unwrap().block_on(engine.create_peer_connection(config)) {
            Ok(connection_id) => {
                match CString::new(connection_id) {
                    Ok(c_string) => {
                        *connection_id_out = c_string.into_raw();
                        FFI_SUCCESS
                    }
                    Err(_) => FFI_ERROR_UNKNOWN,
                }
            }
            Err(_) => FFI_ERROR_CONNECTION_FAILED,
        }
    }
}

#[no_mangle]
pub extern "C" fn webrtc_engine_send_data(
    handle: WebRTCEngineHandle,
    connection_id: *const c_char,
    data: *const u8,
    data_len: usize,
) -> c_int {
    if handle.is_null() || connection_id.is_null() || data.is_null() {
        return FFI_ERROR_INVALID_PARAM;
    }

    unsafe {
        let engine = &*(handle as *const WebRTCEngine);
        let connection_id_str = match CStr::from_ptr(connection_id).to_str() {
            Ok(s) => s,
            Err(_) => return FFI_ERROR_INVALID_PARAM,
        };

        let data_slice = std::slice::from_raw_parts(data, data_len);
        
        match tokio::runtime::Runtime::new().unwrap().block_on(
            engine.send_data(connection_id_str, data_slice.to_vec())
        ) {
            Ok(_) => FFI_SUCCESS,
            Err(_) => FFI_ERROR_UNKNOWN,
        }
    }
}

// Signaling Client FFI functions
#[no_mangle]
pub extern "C" fn signaling_client_create(server_url: *const c_char) -> SignalingClientHandle {
    if server_url.is_null() {
        return std::ptr::null_mut();
    }

    unsafe {
        let url_str = match CStr::from_ptr(server_url).to_str() {
            Ok(s) => s.to_string(),
            Err(_) => return std::ptr::null_mut(),
        };

        match SignalingClient::new(url_str) {
            Ok(client) => Box::into_raw(Box::new(client)) as SignalingClientHandle,
            Err(_) => std::ptr::null_mut(),
        }
    }
}

#[no_mangle]
pub extern "C" fn signaling_client_destroy(handle: SignalingClientHandle) {
    if !handle.is_null() {
        unsafe {
            let _ = Box::from_raw(handle as *mut SignalingClient);
        }
    }
}

#[no_mangle]
pub extern "C" fn signaling_client_connect(handle: SignalingClientHandle) -> c_int {
    if handle.is_null() {
        return FFI_ERROR_INVALID_PARAM;
    }

    unsafe {
        let client = &mut *(handle as *mut SignalingClient);
        match tokio::runtime::Runtime::new().unwrap().block_on(client.connect()) {
            Ok(_) => FFI_SUCCESS,
            Err(_) => FFI_ERROR_CONNECTION_FAILED,
        }
    }
}

#[no_mangle]
pub extern "C" fn signaling_client_register_device(
    handle: SignalingClientHandle,
    device_info: *const CDeviceInfo,
    device_id_out: *mut *mut c_char,
) -> c_int {
    if handle.is_null() || device_info.is_null() || device_id_out.is_null() {
        return FFI_ERROR_INVALID_PARAM;
    }

    unsafe {
        let client = &mut *(handle as *mut SignalingClient);
        let device_info_ref = &*device_info;

        let device_info_rust = crate::signaling::DeviceInfo {
            device_id: CStr::from_ptr(device_info_ref.device_id).to_string_lossy().to_string(),
            device_name: CStr::from_ptr(device_info_ref.device_name).to_string_lossy().to_string(),
            platform: CStr::from_ptr(device_info_ref.platform).to_string_lossy().to_string(),
            version: CStr::from_ptr(device_info_ref.version).to_string_lossy().to_string(),
            capabilities: crate::signaling::DeviceCapabilities {
                screen_capture: true,
                audio_capture: true,
                file_transfer: true,
                input_control: true,
            },
        };

        match tokio::runtime::Runtime::new().unwrap().block_on(client.register_device(device_info_rust)) {
            Ok(device_id) => {
                match CString::new(device_id) {
                    Ok(c_string) => {
                        *device_id_out = c_string.into_raw();
                        FFI_SUCCESS
                    }
                    Err(_) => FFI_ERROR_UNKNOWN,
                }
            }
            Err(_) => FFI_ERROR_CONNECTION_FAILED,
        }
    }
}

// Memory management for returned strings
#[no_mangle]
pub extern "C" fn free_string(ptr: *mut c_char) {
    if !ptr.is_null() {
        unsafe {
            let _ = CString::from_raw(ptr);
        }
    }
}

// Utility functions for error handling
#[no_mangle]
pub extern "C" fn get_last_error_message() -> *const c_char {
    // Placeholder - would return actual error message
    b"Unknown error\0".as_ptr() as *const c_char
}

// Initialize logging from FFI
#[no_mangle]
pub extern "C" fn init_logging(level: c_int) -> c_int {
    let log_level = match level {
        0 => tracing::Level::ERROR,
        1 => tracing::Level::WARN,
        2 => tracing::Level::INFO,
        3 => tracing::Level::DEBUG,
        _ => tracing::Level::TRACE,
    };

    tracing_subscriber::fmt()
        .with_max_level(log_level)
        .init();

    FFI_SUCCESS
}