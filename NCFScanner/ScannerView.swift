import SwiftUI
import AVFoundation
import Vision

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedNCF: String = ""
    @State private var showResult = false
    
    var body: some View {
        ZStack {
            // Cámara
            CameraPreview()
                .ignoresSafeArea()
            
            // Overlay
            VStack {
                // Top bar
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Escanear Comprobante")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    Color.clear.frame(width: 44, height: 44)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                Spacer()
                
                // Marco de escaneo
                RoundedRectangle(cornerRadius: 16)
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: 300, height: 180)
                    .overlay(
                        Text("Apunta al comprobante")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 200)
                    )
                
                Spacer()
                
                // Botón capturar
                Button(action: {
                    // Por ahora simula un NCF escaneado
                    scannedNCF = "B0100000004"
                    showResult = true
                }) {
                    Circle()
                        .fill(Color.white)
                        .frame(width: 72, height: 72)
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                .frame(width: 84, height: 84)
                        )
                }
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showResult) {
            ScannedResultView(ncf: scannedNCF, onSave: {
                dismiss()
            })
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        
        let session = AVCaptureSession()
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        
        session.addInput(input)
        view.session = session
        
        let preview = AVCaptureVideoPreviewLayer(session: session)
        preview.videoGravity = .resizeAspectFill
        view.previewLayer = preview
        view.layer.addSublayer(preview)
        
        DispatchQueue.global(qos: .background).async {
            session.startRunning()
        }
        
        return view
    }
    
    func updateUIView(_ uiView: PreviewUIView, context: Context) {}
}

class PreviewUIView: UIView {
    var previewLayer: AVCaptureVideoPreviewLayer?
    var session: AVCaptureSession?
    
    override func layoutSubviews() {
        super.layoutSubviews()
        previewLayer?.frame = bounds
    }
}
// MARK: - Result View
struct ScannedResultView: View {
    let ncf: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var establecimiento = ""
    @State private var monto = ""
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Handle
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 16)
                
                VStack(spacing: 8) {
                    Text("NCF Detectado")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text(ncf)
                        .font(.system(size: 24, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                }
                
                VStack(spacing: 16) {
                    // Campo establecimiento
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Establecimiento")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        TextField("Ej: La Sirena", text: $establecimiento)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    // Campo monto
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Monto (RD$)")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        TextField("0.00", text: $monto)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .keyboardType(.decimalPad)
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                
                // Botón guardar
                Button(action: {
                    onSave()
                }) {
                    Text("Guardar Comprobante")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.white)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                }
                .padding(.horizontal, 24)
                
                Spacer()
            }
        }
    }
}
//  ScannerView.swift
//  NCFScanner
//
//  Created by Angel Izquierdo on 11/4/26.
//

