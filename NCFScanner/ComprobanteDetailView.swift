import SwiftUI

struct ComprobanteDetailView: View {
    let comprobante: Comprobante
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                HStack {
                    Button(action: { dismiss() }) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    Spacer()
                    Text("Detalle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                    Spacer()
                    // Balance visual
                    Color.clear.frame(width: 44, height: 44)
                    Button(action: {dismiss ()}) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(12)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Monto principal
                        VStack(spacing: 8) {
                            Text("RD$ \(comprobante.monto, specifier: "%.2f")")
                                .font(.system(size: 42, weight: .bold))
                                .foregroundColor(.white)
                            Text(comprobante.establecimiento)
                                .font(.system(size: 16))
                                .foregroundColor(.gray)
                        }
                        .padding(.top, 32)
                        .padding(.bottom, 8)
                        
                        // NCF Card
                        VStack(spacing: 0) {
                            InfoRow(label: "NCF", value: comprobante.ncf, isMonospaced: true)
                            Divider().background(Color.white.opacity(0.08))
                            InfoRow(label: "Establecimiento", value: comprobante.establecimiento)
                            Divider().background(Color.white.opacity(0.08))
                            InfoRow(label: "Monto", value: "RD$ \(String(format: "%.2f", comprobante.monto))")
                            Divider().background(Color.white.opacity(0.08))
                            InfoRow(label: "Fecha", value: comprobante.fecha)
                        }
                        .background(Color.white.opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .padding(.horizontal, 24)
                        
                        // Botón copiar NCF
                        Button(action: {
                            UIPasteboard.general.string = comprobante.ncf
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.on.doc")
                                Text("Copiar NCF")
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.black)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.white)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal, 24)
                    }
                }
            }
        }
        .navigationBarHidden(true)
    }
}

// MARK: - Info Row
struct InfoRow: View {
    let label: String
    let value: String
    var isMonospaced: Bool = false
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.gray)
            Spacer()
            Text(value)
                .font(isMonospaced
                    ? .system(size: 14, weight: .medium, design: .monospaced)
                    : .system(size: 14, weight: .medium))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}

#Preview {
    ComprobanteDetailView(comprobante: mockComprobantes[0])
}
//  Created by Angel Izquierdo on 11/4/26.
//

