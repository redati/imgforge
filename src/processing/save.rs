use libvips::bindings as ffi;
use libvips::ops::{ForeignHeifCompression, ForeignHeifEncoder, ForeignSubsample, ForeignKeep};
use libvips::{ops, VipsImage};

/// Saves an image to bytes in the specified format.
pub fn save_image(img: VipsImage, format: &str, _quality: u8) -> Result<Vec<u8>, String> {
    match format {
        "jpeg" | "jpg" => ops::jpegsave_buffer(&img).map_err(|e| format!("Error encoding JPEG: {}", e)),
        "png" => ops::pngsave_buffer(&img).map_err(|e| format!("Error encoding PNG: {}", e)),
        "webp" => ops::webpsave_buffer(&img).map_err(|e| format!("Error encoding WebP: {}", e)),
        "tiff" => ops::tiffsave_buffer(&img).map_err(|e| format!("Error encoding TIFF: {}", e)),
        "gif" => ops::gifsave_buffer(&img).map_err(|e| format!("Error encoding GIF: {}", e)),
        "avif" => {
            let options = ops::HeifsaveBufferOptions {
                q: _quality as i32,
                bitdepth: 8,
                lossless: false,
                compression: ForeignHeifCompression::Av1,
                effort: 3,
                subsample_mode: ForeignSubsample::Off,
                encoder: ForeignHeifEncoder::Svt,
                keep: ForeignKeep::Icc,
                ..ops::HeifsaveBufferOptions::default()
            };
            ops::heifsave_buffer_with_opts(&img, &options).map_err(|e| {
                unsafe {

                    let error_buffer = ffi::vips_error_buffer();
                    
                    let vips_details = if error_buffer.is_null() {
                        "No VIPS error details available".to_string()
                    } else {
                        std::ffi::CStr::from_ptr(error_buffer)
                            .to_string_lossy()
                            .into_owned()
                    };
                    
                    // Limpa o buffer de erro para a próxima operação
                    ffi::vips_error_clear();
                    format!("Error encoding avif: {} vips error {}", e, vips_details)
                }
            })
        }
        _ => Err(format!("Unsupported output format: {}", format)),
    }
}
