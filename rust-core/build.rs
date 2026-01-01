fn main() {
    // Build FFI bindings if needed
    println!("cargo:rerun-if-changed=src/ffi.rs");
    
    // Add any platform-specific build configuration here
    #[cfg(target_os = "windows")]
    {
        println!("cargo:rustc-link-lib=user32");
        println!("cargo:rustc-link-lib=gdi32");
    }
    
    #[cfg(target_os = "macos")]
    {
        println!("cargo:rustc-link-lib=framework=CoreGraphics");
        println!("cargo:rustc-link-lib=framework=CoreFoundation");
    }
    
    #[cfg(target_os = "linux")]
    {
        println!("cargo:rustc-link-lib=X11");
        println!("cargo:rustc-link-lib=Xrandr");
    }
}