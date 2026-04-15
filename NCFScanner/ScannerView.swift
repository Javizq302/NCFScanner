import SwiftUI
import AVFoundation
import Vision

struct ScannedData {
    var ncf: String
    var empresa: String
    var fecha: String
    var total: String
}

struct ScannerView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var scannedResult: ScannedData? = nil
    @State private var showResult = false
    @State private var isProcessing = false
    

    
    // Referencia a la cámara para capturar foto
    let cameraController = CameraController()
    
    var body: some View {
        ZStack {
            // Cámara
            CameraPreview(controller: cameraController)
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
                    .frame(width: 260, height: 380)
                    .overlay(
                        Text("Apunta al comprobante")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 420)
                    )
                
                Spacer()
                
                // Botón capturar
                Button(action: {
                    guard !isProcessing else { return }
                    isProcessing = true
                    cameraController.capturePhoto { image in
                        guard let image = image else {
                            isProcessing = false
                            return
                        }
                        recognizeNCF(from: image)
                    }
                }) {
                    ZStack {
                        Circle()
                            .fill(Color.white)
                            .frame(width: 72, height: 72)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.3), lineWidth: 4)
                                    .frame(width: 84, height: 84)
                            )
                        if isProcessing {
                            ProgressView()
                                .tint(.black)
                        }
                    }
                }
                .padding(.bottom, 48)
            }
        }
        .sheet(isPresented: $showResult) {
            if let result = scannedResult {
                ScannedResultView(data: result, onSave: { dismiss() })
            }
        }
        .navigationBarHidden(true)
    }
    
    // MARK: - OCR con Vision
    private func recognizeNCF(from image: UIImage) {
        guard let cgImage = image.cgImage else {
            isProcessing = false
            return
        }
        
        let request = VNRecognizeTextRequest { request, error in
            defer { DispatchQueue.main.async { isProcessing = false } }
            
            guard let observations = request.results as? [VNRecognizedTextObservation] else {
                print("=== ERROR: No se pudo obtener observaciones ===")
                print("Error: \(String(describing: error))")
                return
            }
            
            let lines = observations.compactMap { $0.topCandidates(1).first?.string }
            print("=== LÍNEAS RECONOCIDAS ===")
            lines.enumerated().forEach { print("\($0.offset): \($0.element)") }
            let fullText = lines.joined(separator: " ")
            
            print("Texto reconocido: \(fullText)")
            print("Líneas: \(lines)")
            
            let ncf = extractNCF(from: fullText) ?? "No detectado"
            let fecha = extractFecha(from: fullText) ?? "No detectada"
            let total = extractTotal(from: fullText) ?? "0.00"
            let empresa = extractEmpresa(from: lines) ?? "No detectada"
            
            DispatchQueue.main.async {
                scannedResult = ScannedData(
                    ncf: ncf,
                    empresa: empresa,
                    fecha: fecha,
                    total: total
                )
                showResult = true
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-DO", "es", "en"]
        request.usesLanguageCorrection = false
        
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try handler.perform([request])
            } catch {
                print("=== ERROR Vision: \(error) ===")
                DispatchQueue.main.async { self.isProcessing = false }
            }
        }
    }

    // MARK: - Extractors
    private func extractNCF(from text: String) -> String? {
        let patterns = [
            // Formato estándar: B o E + 10-12 dígitos como palabra sola
            "\\b[BE]\\d{10,12}\\b",
            // Formato con ceros adelante: extrae solo desde la B o E
            "[BE]\\d{10,12}",
            // Con espacios posibles entre grupos
            "\\b[BE]\\s?\\d{3}\\s?\\d{7,8}\\b",
            // Pegado a otros números — busca B o E seguido de dígitos
            "(?<=[0-9])[BE]\\d{10,12}",
            // Secuencia larga que contenga B o E en el medio
            "\\d*[BE]\\d{10,12}"
        ]
        
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                let matches = regex.matches(in: text, range: range)
                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        var result = String(text[matchRange])
                            .replacingOccurrences(of: " ", with: "")
                        
                        // Si viene con ceros adelante, recortamos desde la B o E
                        if let bRange = result.range(of: "[BE]", options: .regularExpression) {
                            result = String(result[bRange.lowerBound...])
                        }
                        
                        // Validamos que tenga la longitud correcta de un NCF
                        if result.count >= 11 && result.count <= 13 {
                            return result
                        }
                    }
                }
            }
        }
        return nil
    }

    private func extractFecha(from text: String) -> String? {
        let lines = text.components(separatedBy: " ")
        
        // Primero intentamos encontrar fecha cerca de palabras clave
        let keywords = ["fecha", "emisión", "emision", "emitido", "date", "fec"]
        let fullLower = text.lowercased()
        
        for keyword in keywords {
            if let keywordRange = fullLower.range(of: keyword) {
                // Tomamos el texto después del keyword
                let afterKeyword = String(text[keywordRange.upperBound...])
                let datePatterns = [
                    "\\d{2}/\\d{2}/\\d{4}",
                    "\\d{2}-\\d{2}-\\d{4}",
                    "\\d{2}\\.\\d{2}\\.\\d{4}"
                ]
                for pattern in datePatterns {
                    if let regex = try? NSRegularExpression(pattern: pattern),
                       let match = regex.firstMatch(in: afterKeyword, range: NSRange(afterKeyword.startIndex..., in: afterKeyword)),
                       let matchRange = Range(match.range, in: afterKeyword) {
                        return String(afterKeyword[matchRange])
                    }
                }
            }
        }
        
        // Si no encontró cerca de keyword, busca la última fecha del texto
        // (normalmente la fecha de emisión está al final, no al inicio)
        let datePatterns = [
            "\\d{2}/\\d{2}/\\d{4}",
            "\\d{2}-\\d{2}-\\d{4}",
            "\\d{2}\\.\\d{2}\\.\\d{4}"
        ]
        
        var allDates: [String] = []
        for pattern in datePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern) {
                let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
                for match in matches {
                    if let matchRange = Range(match.range, in: text) {
                        allDates.append(String(text[matchRange]))
                    }
                }
            }
        }
        
        // Retornamos la última fecha encontrada si hay varias
        return allDates.last
    }

    private func extractTotal(from text: String) -> String? {
        let fullLower = text.lowercased()
        
        // Primero buscamos cerca de palabras clave de total
        // Ignoramos subtotal, itbis, impuesto, descuento
        let keywords = ["total", "monto total", "importe total", "gran total", "total a pagar"]
        let ignoreKeywords = ["subtotal", "sub-total", "sub total", "itbis", "impuesto", "descuento", "propina"]
        
        let lines = text.components(separatedBy: CharacterSet.newlines)
        let spaceLines = text.components(separatedBy: " ")
        
        // Buscamos línea por línea
        for line in lines {
            let lineLower = line.lowercased()
            
            // Ignoramos líneas con subtotal, itbis, etc.
            let shouldIgnore = ignoreKeywords.contains { lineLower.contains($0) }
            guard !shouldIgnore else { continue }
            
            // Buscamos líneas que contengan "total"
            let hasKeyword = keywords.contains { lineLower.contains($0) }
            guard hasKeyword else { continue }
            
            // Extraemos el número de esa línea
            let amountPattern = "[\\d,\\.]+(?:\\.\\d{2})"
            if let regex = try? NSRegularExpression(pattern: amountPattern),
               let match = regex.firstMatch(in: line, range: NSRange(line.startIndex..., in: line)),
               let matchRange = Range(match.range, in: line) {
                return String(line[matchRange])
            }
        }
        
        // Fallback — buscar el número más grande del texto
        // (el total suele ser el monto más alto en la factura)
        let amountPattern = "[\\d,\\.]+(?:\\.\\d{2})"
        if let regex = try? NSRegularExpression(pattern: amountPattern) {
            let matches = regex.matches(in: text, range: NSRange(text.startIndex..., in: text))
            let amounts = matches.compactMap { match -> Double? in
                guard let range = Range(match.range, in: text) else { return nil }
                let str = String(text[range]).replacingOccurrences(of: ",", with: "")
                return Double(str)
            }
            if let maxAmount = amounts.max() {
                return String(format: "%.2f", maxAmount)
            }
        }
        
        return nil
    }

    private func extractEmpresa(from lines: [String]) -> String? {
        let ignorePatterns = [
            "\\b[BE]\\d{10,12}\\b",
            "\\d{2}/\\d{2}/\\d{4}",
            "\\d{2}-\\d{2}-\\d{4}",
            "e-NCF", "NCF", "NIF", "RNC", "DGII",
            "COMPROBANTE", "FACTURA", "CREDITO",
            "TEL", "FAX", "WWW\\.", "HTTP", "@",
            "CLIENTE", "FECHA", "CANT", "PRODUCTO",
            "SUBTOTAL", "TOTAL", "ITBIS", "VALOR",
            "AUTOPISTA", "PLAZA", "AVE\\.", "CALLE", "KM\\.",
            "SANTO DOMINGO", "SANTIAGO",
        ]
        
        let businessIndicators = ["SRL", "S.R.L", "S.A.", " SA ", "EIRL",
                                  "CORP", "GROUP", "VIP", "CIA"]
        
        // Filtramos líneas válidas
        let cleanLines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Ignorar líneas muy cortas o muy largas
            guard trimmed.count >= 3 && trimmed.count <= 60 else { return false }
            
            // Ignorar líneas con demasiados caracteres raros (basura de QR, asteriscos, cirílico)
            let validChars = trimmed.filter { $0.isLetter || $0.isNumber || $0.isWhitespace || $0 == "." || $0 == "," || $0 == "-" }
            let ratio = Double(validChars.count) / Double(trimmed.count)
            guard ratio > 0.7 else { return false }
            
            // Ignorar líneas que contengan patrones malos
            let shouldIgnore = ignorePatterns.contains { pattern in
                if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                    let range = NSRange(trimmed.startIndex..., in: trimmed)
                    return regex.firstMatch(in: trimmed, range: range) != nil
                }
                return trimmed.uppercased().contains(pattern)
            }
            
            return !shouldIgnore
        }
        
        // Primero buscamos línea con indicador de empresa (SRL, SA, etc.)
        for line in cleanLines.prefix(10) {
            let upper = line.uppercased()
            if businessIndicators.contains(where: { upper.contains($0) }) {
                return line.trimmingCharacters(in: .whitespaces)
            }
        }
        
        // Si no hay indicador, tomamos la primera línea limpia
        return cleanLines.first?.trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Camera Controller
class CameraController: NSObject, AVCapturePhotoCaptureDelegate {
    var session: AVCaptureSession?
    var photoOutput: AVCapturePhotoOutput?
    var photoCaptureCompletion: ((UIImage?) -> Void)?
    
    func capturePhoto(completion: @escaping (UIImage?) -> Void) {
        photoCaptureCompletion = completion
        let settings = AVCapturePhotoSettings()
        photoOutput?.capturePhoto(with: settings, delegate: self)
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photo: AVCapturePhoto,
                     error: Error?) {
        guard let data = photo.fileDataRepresentation(),
              let image = UIImage(data: data) else {
            photoCaptureCompletion?(nil)
            return
        }
        photoCaptureCompletion?(image)
    }
}

// MARK: - Camera Preview
struct CameraPreview: UIViewRepresentable {
    let controller: CameraController
    
    func makeUIView(context: Context) -> PreviewUIView {
        let view = PreviewUIView()
        view.backgroundColor = .black
        
        let session = AVCaptureSession()
        session.sessionPreset = .photo
        
        guard let device = AVCaptureDevice.default(for: .video),
              let input = try? AVCaptureDeviceInput(device: device) else {
            return view
        }
        
        session.addInput(input)
        
        // Output para capturar fotos
        let photoOutput = AVCapturePhotoOutput()
        if session.canAddOutput(photoOutput) {
            session.addOutput(photoOutput)
        }
        
        controller.session = session
        controller.photoOutput = photoOutput
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
    let data: ScannedData
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var establecimiento: String
    @State private var monto: String
    @State private var fecha: String
    
    init(data: ScannedData, onSave: @escaping () -> Void) {
        self.data = data
        self.onSave = onSave
        _establecimiento = State(initialValue: data.empresa)
        _monto = State(initialValue: data.total)
        _fecha = State(initialValue: data.fecha)
    }
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 32) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 16)
                
                VStack(spacing: 8) {
                    Text("NCF Detectado")
                        .font(.system(size: 13))
                        .foregroundColor(.gray)
                    Text(data.ncf)
                        .font(.system(size: 22, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                }
                
                VStack(spacing: 16) {
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
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fecha de emisión")
                            .font(.system(size: 13))
                            .foregroundColor(.gray)
                        TextField("dd/mm/yyyy", text: $fecha)
                            .font(.system(size: 15))
                            .foregroundColor(.white)
                            .padding(14)
                            .background(Color.white.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.horizontal, 24)
                
                Button(action: { onSave() }) {
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
