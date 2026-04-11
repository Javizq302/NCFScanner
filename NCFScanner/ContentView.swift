import SwiftUI


struct ContentView: View {
    @State private var showScanner = false
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()
                
                VStack(spacing: 0) {
                    // Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("NCF Scanner")
                                .font(.largeTitle)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                            Text("3 comprobantes guardados")
                                .font(.subheadline)
                                .foregroundColor(.gray)
                        }
                        Spacer()
                        Button(action: { showScanner = true }) {
                            Image(systemName: "qrcode.viewfinder")
                                .font(.system(size: 22))
                                .foregroundColor(.white)
                                .padding(12)
                                .background(Color.white.opacity(0.1))
                                .clipShape(Circle())
                        }
                        .sheet(isPresented: $showScanner) {
                            ScannerView()
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 20)
                    .padding(.bottom, 32)
                    
                    // Lista de comprobantes
                    ScrollView {
                        VStack(spacing: 12) {
                            ForEach(mockComprobantes) { comprobante in
                                NavigationLink(destination: ComprobanteDetailView(comprobante: comprobante)) {
                                    ComprobanteCard(comprobante: comprobante)
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
    }
}

// MARK: - Card Component
struct ComprobanteCard: View {
    let comprobante: Comprobante
    
    var body: some View {
        HStack(spacing: 16) {
            // Icono
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.08))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "doc.text")
                        .foregroundColor(.white)
                        .font(.system(size: 20))
                )
            
            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(comprobante.establecimiento)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                Text(comprobante.ncf)
                    .font(.system(size: 12, weight: .regular, design: .monospaced))
                    .foregroundColor(.gray)
            }
            
            Spacer()
            
            // Monto y fecha
            VStack(alignment: .trailing, spacing: 4) {
                Text("RD$ \(comprobante.monto, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(comprobante.fecha)
                    .font(.system(size: 11))
                    .foregroundColor(.gray)
            }
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - Model (temporal, mock data)
struct Comprobante: Identifiable {
    let id = UUID()
    let ncf: String
    let establecimiento: String
    let monto: Double
    let fecha: String
}

let mockComprobantes = [
    Comprobante(ncf: "B0100000001", establecimiento: "La Sirena", monto: 1850.00, fecha: "11 abr 2026"),
    Comprobante(ncf: "B0100000002", establecimiento: "Supermercado Nacional", monto: 3200.50, fecha: "10 abr 2026"),
    Comprobante(ncf: "E310000000001", establecimiento: "Farmacia Carol", monto: 650.00, fecha: "9 abr 2026"),
]

#Preview {
    ContentView()
}
