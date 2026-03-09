//
//  CameraPreviewView.swift
//  IsaretDiliCevirme
//
//  Created by Mahmut Arslan on 9.03.2026.
//

import SwiftUI
import AVFoundation

/// A UIViewRepresentable that wraps AVCaptureVideoPreviewLayer for SwiftUI.
///
/// This bridges UIKit's preview layer into SwiftUI so we can display
/// a live camera feed underneath our landmark overlay.
struct CameraPreviewView: UIViewRepresentable {

    let session: AVCaptureSession

    func makeUIView(context: Context) -> CameraPreviewUIView {
        let view = CameraPreviewUIView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: CameraPreviewUIView, context: Context) {
        // Session is set once; no updates needed
    }
}

/// Custom UIView that hosts an AVCaptureVideoPreviewLayer as its layer class.
final class CameraPreviewUIView: UIView {
    override class var layerClass: AnyClass {
        AVCaptureVideoPreviewLayer.self
    }

    var previewLayer: AVCaptureVideoPreviewLayer {
        layer as! AVCaptureVideoPreviewLayer
    }
}
