//
//  CMSampleBuffer+Image.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 28.03.2026.
//

import CoreMedia
import UIKit
import AVFoundation

extension CMSampleBuffer {
    /// Converts a CMSampleBuffer to a properly oriented UIImage for the ML model.
    ///
    /// The raw pixel buffer from the camera is in the sensor's native orientation:
    /// - Back camera: landscape with home button on the right → needs `.right` rotation
    /// - Front camera: landscape, flipped & upside-down → needs `.leftMirrored`
    ///
    /// After applying the correct UIImage orientation, we bake it into the pixels
    /// so the JPEG sent to the backend is always a clean, portrait-oriented image.
    func toUIImage(frontCamera: Bool = true) -> UIImage? {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(self) else {
            return nil
        }
        
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()
        
        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else {
            return nil
        }
        
        // Choose the correct orientation based on camera
        let orientation: UIImage.Orientation = frontCamera ? .leftMirrored : .right
        let image = UIImage(cgImage: cgImage, scale: 1.0, orientation: orientation)
        
        // Bake the orientation into the actual pixel data
        // so the JPEG has correct pixels (no EXIF rotation needed)
        return image.renderedImage()
    }
}

extension UIImage {
    /// Renders the image into a new context, applying any orientation transform
    /// into the actual pixel data. The result always has .up orientation.
    func renderedImage() -> UIImage {
        if imageOrientation == .up {
            return self
        }
        
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1.0
        
        let renderer = UIGraphicsImageRenderer(size: size, format: format)
        let rendered = renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
        
        return rendered
    }
}
