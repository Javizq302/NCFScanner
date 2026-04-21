import SwiftUI
import AVFoundation
import Vision

private extension CGImagePropertyOrientation {
    init(_ uiOrientation: UIImage.Orientation) {
        switch uiOrientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}

struct ScannedData {
    var rnc: String
    var ncf: String
    var empresa: String
    var fecha: String
    var subtotal: String
    var itbis: String
    var total: String
    var metodoPago: String
}

// Línea de OCR con su posición en la imagen (coords Vision normalizadas, origen abajo-izquierda)
struct OCRLine {
    let text: String
    let box: CGRect
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
                    .frame(width: 260, height: 420)
                    .overlay(
                        Text("Apunta la Factura")
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.top, 440)
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
            
            let ocrLines: [OCRLine] = observations.compactMap { obs in
                guard let text = obs.topCandidates(1).first?.string else { return nil }
                return OCRLine(text: text, box: obs.boundingBox)
            }
            let lines = ocrLines.map { $0.text }
            print("=== LÍNEAS RECONOCIDAS ===")
            ocrLines.enumerated().forEach { i, l in
                print("\(i): [y=\(String(format: "%.3f", l.box.midY))] \(l.text)")
            }
            let fullText = lines.joined(separator: " ")

            let rnc = extractRNC(from: fullText) ?? "No detectado"
            let ncf = extractNCF(from: fullText) ?? "No detectado"
            let fecha = extractFecha(from: fullText) ?? "No detectada"
            let subtotalResult = extractSubtotal(from: ocrLines)
            let subtotal = subtotalResult?.amount ?? "0.00"
            let excludedBoxes: [CGRect] = subtotalResult.map { [$0.usedBox] } ?? []
            let itbis = extractITBIS(from: ocrLines, excludingBoxes: excludedBoxes) ?? "0.00"
            let total = extractTotal(from: ocrLines) ?? "0.00"
            let empresa = extractEmpresa(from: lines) ?? "No detectada"
            let metodoPago = extractMetodoPago(from: fullText) ?? "No detectado"

            DispatchQueue.main.async {
                scannedResult = ScannedData(
                    rnc: rnc,
                    ncf: ncf,
                    empresa: empresa,
                    fecha: fecha,
                    subtotal: subtotal,
                    itbis: itbis,
                    total: total,
                    metodoPago: metodoPago
                )
                showResult = true
            }
        }
        
        request.recognitionLevel = .accurate
        request.recognitionLanguages = ["es-DO", "es", "en"]
        request.usesLanguageCorrection = false
        
        let orientation = CGImagePropertyOrientation(image.imageOrientation)
        let handler = VNImageRequestHandler(cgImage: cgImage, orientation: orientation, options: [:])
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

    // MARK: - Amount helpers
    // Monto con 2 decimales obligatorios — soporta miles con coma: 1,262.72 / 227.29 / 1490.01
    private static let amountRegex: NSRegularExpression = {
        try! NSRegularExpression(pattern: #"(?<!\d)(?:\d{1,3}(?:,\d{3})+|\d+)\.\d{2}(?!\d)"#)
    }()

    private func firstAmount(in text: String) -> String? {
        let range = NSRange(text.startIndex..., in: text)
        guard let match = Self.amountRegex.firstMatch(in: text, range: range),
              let r = Range(match.range, in: text) else { return nil }
        return String(text[r])
    }

    private func parseAmount(_ s: String) -> Double? {
        Double(s.replacingOccurrences(of: ",", with: ""))
    }

    // Busca el monto pareado con la línea-label, eligiendo el monto con Y
    // más cercano al label (siempre que esté a la derecha). Ignora observaciones
    // excluidas (usadas para evitar que ITBIS devuelva el mismo monto que el subtotal).
    private func amountOnSameRow(
        as labelBox: CGRect,
        in lines: [OCRLine],
        excludingBoxes excluded: [CGRect] = []
    ) -> String? {
        // 1) Si el label ya trae un monto en su propio texto, usarlo.
        if let labelLine = lines.first(where: { $0.box == labelBox }),
           let amt = firstAmount(in: labelLine.text) {
            return amt
        }

        // 2) Entre todos los montos a la derecha del label, elegir el de Y más cercano.
        let maxYDist: CGFloat = 0.03
        let best = lines.compactMap { line -> (OCRLine, String, CGFloat)? in
            guard line.box != labelBox,
                  !excluded.contains(line.box),
                  line.box.minX > labelBox.minX,
                  let amt = firstAmount(in: line.text) else { return nil }
            return (line, amt, abs(line.box.midY - labelBox.midY))
        }
        .filter { $0.2 < maxYDist }
        .min { $0.2 < $1.2 }

        return best?.1
    }

    private func extractTotal(from lines: [OCRLine]) -> String? {
        let keywords = ["total"]
        // "total en dolar"/USD es monto alterno en dólares — ignorar
        let exclude = ["subtotal", "sub-total", "sub total", "en dolar", "en dólar", "dolar", "dólar", "usd"]

        var candidates: [Double] = []
        for line in lines {
            let lower = line.text.lowercased()
            guard keywords.contains(where: { lower.contains($0) }) else { continue }
            guard !exclude.contains(where: { lower.contains($0) }) else { continue }
            if let amt = amountOnSameRow(as: line.box, in: lines),
               let val = parseAmount(amt) {
                candidates.append(val)
            }
        }
        // Entre matches de "total", el grand total es el más alto
        if let max = candidates.max() {
            return String(format: "%.2f", max)
        }

        // Fallback — monto más alto de toda la factura
        let allAmounts: [Double] = lines.compactMap { line in
            firstAmount(in: line.text).flatMap(parseAmount)
        }
        if let max = allAmounts.max() {
            return String(format: "%.2f", max)
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

    // MARK: - RNC Extractor
    private func extractRNC(from text: String) -> String? {
        // RNC en DR: 9 dígitos, a veces con guiones (e.g. 101-12345-1)
        let patterns = [
            "(?:RNC|R\\.N\\.C\\.?)\\s*:?\\s*(\\d{3}-?\\d{5}-?\\d{1})",
            "(?:RNC|R\\.N\\.C\\.?)\\s*:?\\s*(\\d{9})",
            "\\b(\\d{3}-\\d{5}-\\d{1})\\b"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) {
                let range = NSRange(text.startIndex..., in: text)
                if let match = regex.firstMatch(in: text, range: range) {
                    // Capturamos el grupo 1 si existe, sino el match completo
                    let captureRange = match.numberOfRanges > 1 ? match.range(at: 1) : match.range
                    if let resultRange = Range(captureRange, in: text) {
                        return String(text[resultRange])
                    }
                }
            }
        }
        return nil
    }

    // Busca el label y devuelve (monto, box-del-monto-usado) para que el caller
    // pueda excluir esa observación de extracciones subsiguientes.
    private func extractAmount(
        matching keywords: [String],
        excludingKeywords excludeKw: [String] = [],
        from lines: [OCRLine],
        excludingBoxes excluded: [CGRect] = []
    ) -> (amount: String, usedBox: CGRect)? {
        for line in lines {
            let lower = line.text.lowercased()
            guard keywords.contains(where: { lower.contains($0) }) else { continue }
            guard !excludeKw.contains(where: { lower.contains($0) }) else { continue }

            // Si el label trae el monto en el mismo texto, devolvemos su propia box.
            if let amt = firstAmount(in: line.text) {
                return (amt, line.box)
            }
            // Sino, buscamos el monto Y-más-cercano a la derecha.
            if let amt = amountOnSameRow(as: line.box, in: lines, excludingBoxes: excluded) {
                // Devolvemos la box del monto detectado (para excluirlo más adelante).
                if let amountLine = lines.first(where: { $0.box.minX > line.box.minX
                    && firstAmount(in: $0.text) == amt
                    && !excluded.contains($0.box) }) {
                    return (amt, amountLine.box)
                }
                return (amt, line.box)
            }
        }
        return nil
    }

    // MARK: - Subtotal Extractor
    private func extractSubtotal(from lines: [OCRLine]) -> (amount: String, usedBox: CGRect)? {
        let keywords = ["subtotal", "sub-total", "sub total", "monto sin itbis", "base imponible"]
        return extractAmount(matching: keywords, from: lines)
    }

    // MARK: - ITBIS Extractor
    private func extractITBIS(
        from lines: [OCRLine],
        excludingBoxes excluded: [CGRect] = []
    ) -> String? {
        let keywords = ["itbis", "i.t.b.i.s", "impuesto"]
        // "sin itbis" aparece en labels de subtotal — no es el ITBIS facturado
        let excludeKw = ["sin itbis"]
        return extractAmount(
            matching: keywords,
            excludingKeywords: excludeKw,
            from: lines,
            excludingBoxes: excluded
        )?.amount
    }

    // MARK: - Método de Pago Extractor
    private func extractMetodoPago(from text: String) -> String? {
        let upper = text.uppercased()

        let tarjetaKeywords = ["TARJETA", "VISA", "MASTERCARD", "MASTER CARD",
                               "AMEX", "AMERICAN EXPRESS", "DÉBITO", "DEBITO",
                               "CREDITO", "CRÉDITO", "T. CREDITO", "T. DEBITO",
                               "DATAPHONE", "POS", "TERMINAL"]
        let efectivoKeywords = ["EFECTIVO", "CASH", "CONTADO", "EN EFECTIVO"]
        let transferenciaKeywords = ["TRANSFERENCIA", "TRANSFER", "BANRESERVAS",
                                     "BHD", "POPULAR", "SCOTIABANK"]

        for keyword in tarjetaKeywords {
            if upper.contains(keyword) { return "Tarjeta" }
        }
        for keyword in efectivoKeywords {
            if upper.contains(keyword) { return "Efectivo" }
        }
        for keyword in transferenciaKeywords {
            if upper.contains(keyword) { return "Transferencia" }
        }
        return nil
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
    @State private var rnc: String
    @State private var ncf: String
    @State private var establecimiento: String
    @State private var fecha: String
    @State private var subtotal: String
    @State private var itbis: String
    @State private var total: String
    @State private var metodoPago: String
    @FocusState private var ncfFieldFocused: Bool

    init(data: ScannedData, onSave: @escaping () -> Void) {
        self.data = data
        self.onSave = onSave
        _rnc = State(initialValue: data.rnc)
        _ncf = State(initialValue: data.ncf)
        _establecimiento = State(initialValue: data.empresa)
        _fecha = State(initialValue: data.fecha)
        _subtotal = State(initialValue: data.subtotal)
        _itbis = State(initialValue: data.itbis)
        _total = State(initialValue: data.total)
        _metodoPago = State(initialValue: data.metodoPago)
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 0) {
                // Drag indicator
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.3))
                    .frame(width: 40, height: 4)
                    .padding(.top, 12)
                    .padding(.bottom, 24)

                ScrollView {
                    VStack(spacing: 24) {

                        // MARK: - NCF Hero Card
                        VStack(spacing: 16) {
                            // Status icon
                            ZStack {
                                Circle()
                                    .fill(Color.white.opacity(0.08))
                                    .frame(width: 56, height: 56)
                                Image(systemName: ncf == "No detectado" ? "exclamationmark.triangle" : "checkmark")
                                    .font(.system(size: 24, weight: .semibold))
                                    .foregroundColor(ncf == "No detectado" ? .gray : .white)
                            }

                            Text(ncf == "No detectado" ? "NCF No Detectado" : "NCF Detectado")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(.gray)
                                .textCase(.uppercase)
                                .tracking(1.2)

                            // Editable NCF
                            HStack(spacing: 8) {
                                TextField("B0100000000", text: $ncf)
                                    .font(.system(size: 24, weight: .bold, design: .monospaced))
                                    .foregroundColor(.white)
                                    .multilineTextAlignment(.center)
                                    .autocorrectionDisabled()
                                    .textInputAutocapitalization(.characters)
                                    .focused($ncfFieldFocused)

                                Button(action: {
                                    ncfFieldFocused = true
                                }) {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundColor(.gray)
                                        .padding(8)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                            }
                            .padding(.horizontal, 16)
                        }
                        .padding(.vertical, 24)
                        .frame(maxWidth: .infinity)
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)

                        // MARK: - Info Card
                        VStack(spacing: 0) {
                            EditableFieldRow(
                                label: "RNC",
                                icon: "number",
                                placeholder: "000-00000-0",
                                text: $rnc,
                                keyboard: .numberPad
                            )

                            Divider().background(Color.white.opacity(0.06))

                            EditableFieldRow(
                                label: "Establecimiento",
                                icon: "building.2",
                                placeholder: "Ej: La Sirena",
                                text: $establecimiento
                            )

                            Divider().background(Color.white.opacity(0.06))

                            EditableFieldRow(
                                label: "Fecha de compra",
                                icon: "calendar",
                                placeholder: "dd/mm/yyyy",
                                text: $fecha
                            )
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)

                        // MARK: - Montos Card
                        VStack(spacing: 0) {
                            EditableFieldRow(
                                label: "Subtotal (sin ITBIS)",
                                icon: "minus.circle",
                                placeholder: "0.00",
                                text: $subtotal,
                                keyboard: .decimalPad
                            )

                            Divider().background(Color.white.opacity(0.06))

                            EditableFieldRow(
                                label: "ITBIS facturado",
                                icon: "percent",
                                placeholder: "0.00",
                                text: $itbis,
                                keyboard: .decimalPad
                            )

                            Divider().background(Color.white.opacity(0.06))

                            EditableFieldRow(
                                label: "Total",
                                icon: "dollarsign",
                                placeholder: "0.00",
                                text: $total,
                                keyboard: .decimalPad
                            )
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)

                        // MARK: - Método de Pago
                        VStack(spacing: 0) {
                            HStack(spacing: 14) {
                                Image(systemName: "creditcard")
                                    .font(.system(size: 15))
                                    .foregroundColor(.gray)
                                    .frame(width: 20)

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("MÉTODO DE PAGO")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundColor(.gray)
                                        .tracking(0.5)

                                    HStack(spacing: 8) {
                                        ForEach(["Efectivo", "Tarjeta", "Transferencia"], id: \.self) { metodo in
                                            Button(action: {
                                                withAnimation(.easeInOut(duration: 0.15)) {
                                                    metodoPago = metodo
                                                }
                                            }) {
                                                Text(metodo)
                                                    .font(.system(size: 12, weight: .medium))
                                                    .foregroundColor(metodoPago == metodo ? .black : .gray)
                                                    .padding(.horizontal, 12)
                                                    .padding(.vertical, 7)
                                                    .background(
                                                        metodoPago == metodo
                                                            ? Color.white
                                                            : Color.white.opacity(0.06)
                                                    )
                                                    .clipShape(Capsule())
                                            }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)

                        // MARK: - Actions
                        VStack(spacing: 12) {
                            Button(action: { onSave() }) {
                                HStack(spacing: 8) {
                                    Image(systemName: "square.and.arrow.down")
                                        .font(.system(size: 15, weight: .semibold))
                                    Text("Guardar Comprobante")
                                        .font(.system(size: 16, weight: .semibold))
                                }
                                .foregroundColor(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(Color.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }

                            Button(action: { dismiss() }) {
                                Text("Descartar")
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(.gray)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                    }
                    .padding(.bottom, 32)
                }
            }
        }
    }
}

// MARK: - Editable Field Row
struct EditableFieldRow: View {
    let label: String
    let icon: String
    let placeholder: String
    @Binding var text: String
    var keyboard: UIKeyboardType = .default

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15))
                .foregroundColor(.gray)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.gray)
                    .textCase(.uppercase)
                    .tracking(0.5)
                TextField(placeholder, text: $text)
                    .font(.system(size: 15))
                    .foregroundColor(.white)
                    .keyboardType(keyboard)
                    .autocorrectionDisabled()
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
