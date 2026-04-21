# NCFScanner — Project Context

## What is this?
A native iOS app built in Swift/SwiftUI for the Dominican Republic market.
It lets users photograph fiscal receipts (Comprobantes Fiscales) and uses
Apple's Vision framework OCR to automatically extract and save the
NCF (Número de Comprobante Fiscal) code along with all receipt data
needed for monthly DGII tax reporting.

## Portfolio context
This is one of two mobile projects in Angel's dev portfolio:
- NCFScanner → native iOS, Swift/SwiftUI, visual polish + real utility
- Flutter app (TBD) → cross-platform, utility focused

## Tech stack
- **Language:** Swift
- **UI:** SwiftUI
- **Camera:** AVFoundation
- **OCR:** Vision framework
- **Storage:** SwiftData (in progress)
- **IDE:** Xcode
- **Device:** iPhone 12 Pro (physical testing)
- **Bundle ID:** com.izquierdodev.NCFScanner
- **Version:** DEV v0.3.2

## Design language
- **Theme:** Dark, minimalist
- **Background:** Pure black (#000000)
- **Cards:** White opacity overlays (4-6%)
- **Text primary:** White
- **Text secondary:** Gray
- **Accent:** White (buttons, icons)
- **Corner radius:** 14-16px on cards, 14px on buttons
- **Font:** SF Pro system font, monospaced for NCF/RNC codes
- **Labels:** Uppercase with letter tracking for field labels
- **No gradients, no colors** — pure black and white aesthetic

## App screens
1. **HomeView (ContentView)** — list of saved comprobantes, month/year filter grid,
   scan button top right, DEV version badge, dynamic comprobante count per month
2. **ComprobanteDetailView** — full detail with info card (RNC, NCF, establecimiento, fecha),
   montos card (subtotal, ITBIS, total), método de pago badge, copy NCF button
3. **ScannerView** — camera with vertical frame overlay, capture button
4. **ScannedResultView** — sheet with NCF hero card (editable, with pencil icon),
   info fields card, montos card, método de pago chip selector (Efectivo/Tarjeta/Transferencia),
   guardar + descartar buttons

## Data model (Comprobante)
- `id: UUID` — unique identifier
- `rnc: String` — Registro Nacional del Contribuyente (e.g. 101-12345-1)
- `ncf: String` — Número de Comprobante Fiscal (e.g. B0100000001, E310000038393)
- `establecimiento: String` — business name
- `fecha: String` — purchase date (NOT comprobante expiry date)
- `subtotal: Double` — amount before ITBIS
- `itbis: Double` — ITBIS tax amount
- `total: Double` — total amount in RD$
- `metodoPago: String` — "Efectivo", "Tarjeta", or "Transferencia"

## NCF formats in DR
- **Old format:** B + 11 digits → `B0100054382`
- **Electronic format:** E + 11 digits → `E310000038393`
- Sometimes appears with leading zeros: `00000000B0100054382`
- The app strips leading characters and extracts from B or E onward

## OCR extraction logic (ScannerView.swift)
- `extractRNC()` — patterns for RNC keyword + 9 digits, with or without dashes
- `extractNCF()` — regex patterns for B/E + digits, handles leading zeros
- `extractEmpresa()` — scores lines, filters QR/barcode noise, prioritizes
  lines with SRL/SA/CORP, uses valid character ratio > 0.7 to filter junk
- `extractFecha()` — searches near keywords like "Fecha", "Emisión",
  falls back to last date found in text
- `extractSubtotal()` — searches near "Subtotal", "Sub-total", "Base imponible"
- `extractITBIS()` — searches near "ITBIS", "Impuesto" keywords
- `extractTotal()` — searches near "Total" keyword, ignores Subtotal/ITBIS,
  falls back to largest amount in text
- `extractMetodoPago()` — keyword matching for tarjeta (VISA, MASTERCARD, POS...),
  efectivo (CASH, CONTADO...), transferencia (bank names like BANRESERVAS, BHD, POPULAR...)

## Current state
- ✅ HomeView with mock data and monthly filter grid
- ✅ ComprobanteDetailView with all fields + copy NCF button
- ✅ ScannerView with real camera (AVFoundation)
- ✅ OCR working — extracts RNC, NCF, empresa, fecha, subtotal, ITBIS, total, método de pago
- ✅ ScannedResultView with editable NCF and all fields
- ⏳ SwiftData integration (next step)
- ⏳ Replace mock data with real persisted data
- ⏳ Real date filtering (currently simulated with mock data)

## Development workflow
- Code written in Xcode + Claude Code CLI as co-pilot
- Physical device testing on iPhone 12 Pro
- SwiftUI Preview runs on iPhone 17 Pro simulator
- Live Preview on physical device doesn't work reliably (free Apple account limitation)

## Known quirks
- Logo text on receipts gets picked up by Vision before the real company name
  → solved with character ratio filter + business indicator priority
- NCF sometimes appears with leading zeros → solved by extracting from B/E onward
- Total vs Subtotal confusion → solved by ignoring lines with ITBIS/Subtotal keywords
- Camera preview frame must use `layoutSubviews()` override, not `UIScreen.main.bounds`
- Notion captures Cmd+Shift+K before Xcode → use Product > Clean Build Folder menu instead
