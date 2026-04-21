import SwiftUI


struct ContentView: View {
    @State private var showScanner = false
    @State private var selectedMonth: Int = Calendar.current.component(.month, from: Date())
    @State private var selectedYear: Int = Calendar.current.component(.year, from: Date())

    private let monthNames = [
        "Ene", "Feb", "Mar", "Abr", "May", "Jun",
        "Jul", "Ago", "Sep", "Oct", "Nov", "Dic"
    ]

    private let fullMonthNames = [
        "Enero", "Febrero", "Marzo", "Abril", "Mayo", "Junio",
        "Julio", "Agosto", "Septiembre", "Octubre", "Noviembre", "Diciembre"
    ]

    private var selectedMonthLabel: String {
        "\(fullMonthNames[selectedMonth - 1]) \(selectedYear)"
    }

    var filteredComprobantes: [Comprobante] {
        // Solo diseño por ahora — filtrado real vendrá con SwiftData
        return mockComprobantes
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.black
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    // MARK: - Header
                    VStack(alignment: .leading, spacing: 16) {
                        HStack(alignment: .top) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("NCF Scanner")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(filteredComprobantes.count) comprobantes · \(selectedMonthLabel)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.gray)
                            }

                            Spacer()

                            VStack(alignment: .trailing, spacing: 6) {
                                Button(action: { showScanner = true }) {
                                    Image(systemName: "viewfinder")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundColor(.white)
                                        .padding(12)
                                        .background(Color.white.opacity(0.08))
                                        .clipShape(Circle())
                                }
                                .sheet(isPresented: $showScanner) {
                                    ScannerView()
                                }

                                // Version badge
                                Text("DEV v0.3.4")
                                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.gray)
                                    .tracking(0.5)
                            }
                        }

                        // MARK: - Month selector
                        VStack(spacing: 10) {
                            // Year nav
                            HStack {
                                Button(action: {
                                    withAnimation { selectedYear -= 1 }
                                }) {
                                    Image(systemName: "chevron.left")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .padding(8)
                                }

                                Spacer()

                                Text(String(selectedYear))
                                    .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.white)

                                Spacer()

                                Button(action: {
                                    withAnimation { selectedYear += 1 }
                                }) {
                                    Image(systemName: "chevron.right")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(.gray)
                                        .padding(8)
                                }
                            }

                            // Month grid — 2 rows x 6 columns
                            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 6)
                            LazyVGrid(columns: columns, spacing: 6) {
                                ForEach(1...12, id: \.self) { month in
                                    Button(action: {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedMonth = month
                                        }
                                    }) {
                                        Text(monthNames[month - 1])
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(selectedMonth == month ? .black : .gray)
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 8)
                                            .background(
                                                selectedMonth == month
                                                    ? Color.white
                                                    : Color.white.opacity(0.06)
                                            )
                                            .clipShape(RoundedRectangle(cornerRadius: 8))
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .background(Color.white.opacity(0.04))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)

                    // MARK: - List
                    if filteredComprobantes.isEmpty {
                        Spacer()
                        VStack(spacing: 12) {
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 36))
                                .foregroundColor(.white.opacity(0.15))
                            Text("Sin comprobantes")
                                .font(.system(size: 15))
                                .foregroundColor(.gray)
                        }
                        Spacer()
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 10) {
                                ForEach(filteredComprobantes) { comprobante in
                                    NavigationLink(destination: ComprobanteDetailView(comprobante: comprobante)) {
                                        ComprobanteCard(comprobante: comprobante)
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 24)
                            .padding(.bottom, 24)
                        }
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
        HStack(spacing: 14) {
            // Type indicator
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.06))
                .frame(width: 44, height: 44)
                .overlay(
                    Text(String(comprobante.ncf.prefix(1)))
                        .font(.system(size: 17, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                )

            // Info
            VStack(alignment: .leading, spacing: 3) {
                Text(comprobante.establecimiento)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)
                Text(comprobante.ncf)
                    .font(.system(size: 11, weight: .regular, design: .monospaced))
                    .foregroundColor(.white.opacity(0.4))
            }

            Spacer()

            // Amount & date
            VStack(alignment: .trailing, spacing: 3) {
                Text("RD$ \(comprobante.total, specifier: "%.2f")")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                Text(comprobante.fecha)
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.35))
            }

            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.white.opacity(0.2))
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Model (temporal, mock data)
struct Comprobante: Identifiable {
    let id = UUID()
    let rnc: String
    let ncf: String
    let establecimiento: String
    let fecha: String
    let subtotal: Double
    let itbis: Double
    let total: Double
    let metodoPago: String
}

let mockComprobantes = [
    Comprobante(rnc: "101-12345-1", ncf: "B0100000001", establecimiento: "La Sirena", fecha: "11 abr 2026", subtotal: 1567.80, itbis: 282.20, total: 1850.00, metodoPago: "Tarjeta"),
    Comprobante(rnc: "130-98765-3", ncf: "B0100000002", establecimiento: "Supermercado Nacional", fecha: "10 May 2026", subtotal: 2712.29, itbis: 488.21, total: 3200.50, metodoPago: "Efectivo"),
    Comprobante(rnc: "401-55555-2", ncf: "E310000000001", establecimiento: "Farmacia Carol", fecha: "9 Jun 2026", subtotal: 550.85, itbis: 99.15, total: 650.00, metodoPago: "Transferencia"),
]

#Preview {
    ContentView()
}
