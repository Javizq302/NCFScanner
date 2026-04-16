# NCFScanner — Project Context

## What is this?
A native iOS app built in Swift/SwiftUI for the Dominican Republic market.
It lets users photograph fiscal receipts (Comprobantes Fiscales) and uses
Apple's Vision framework OCR to automatically extract and save the
NCF (Número de Comprobante Fiscal) code along with other receipt data.

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

## Design language
- **Theme:** Dark, minimalist
- **Background:** Pure black (#000000)
- **Cards:** White opacity overlays (5-8%)
- **Text primary:** White
- **Text secondary:** Gray
- **Accent:** White (buttons, icons)
- **Corner radius:** 12-16px on cards, 14px on buttons
- **Font:** SF Pro system font, monospaced for NCF codes
- **No gradients, no colors** — pure black and white aesthetic

## App screens
1. **HomeView (ContentView)** — list of saved comprobantes, scan button top right
2. **ComprobanteDetailView** — full detail of one comprobante, copy NCF button
3. **ScannerView** — camera with vertical frame overlay, capture button
4. **ScannedResultView** — sheet showing OCR results, editable fields before saving

## Data model (Comprobante)
- `ncf: String` — Número de Comprobante Fiscal (e.g. B0100000001, E310000038393)
- `establecimiento: String` — business name
- `monto: Double` — total amount in RD$
- `fecha: String` — emission date
- `id: UUID` — unique identifier

## NCF formats in DR
- **Old format:** B + 11 digits → `B0100054382`
- **Electronic format:** E + 11 digits → `E310000038393`
- Sometimes appears with leading zeros: `00000000B0100054382`
- The app strips leading characters and extracts from B or E onward

## OCR extraction logic (ScannerView.swift)
- `extractNCF()` — regex patterns for B/E + digits, handles leading zeros
- `extractEmpresa()` — scores lines, filters QR/barcode noise, prioritizes
  lines with SRL/SA/CORP, uses valid character ratio > 0.7 to filter junk
- `extractFecha()` — searches near keywords like "Fecha", "Emisión",
  falls back to last date found in text
- `extractTotal()` — searches near "Total" keyword, ignores Subtotal/ITBIS,
  falls back to largest amount in text

## Current state
- ✅ HomeView with mock data
- ✅ ComprobanteDetailView with copy NCF button
- ✅ ScannerView with real camera (AVFoundation)
- ✅ OCR working — extracts NCF, empresa, fecha, total
- ⏳ SwiftData integration (next step)
- ⏳ Replace mock data with real persisted data

## Development workflow
- Code written in Xcode
- Claude.ai used as co-pilot (paste code back and forth)
- Physical device testing on iPhone 12 Pro
- SwiftUI Preview runs on iPhone 17 Pro simulator
- Live Preview on physical device doesn't work reliably (free Apple account limitation)

## Known quirks
- Logo text on receipts gets picked up by Vision before the real company name
  → solved with character ratio filter + business indicator priority
- NCF sometimes appears with leading zeros → solved by extracting from B/E onward
- Total vs Subtotal confusion → solved by ignoring lines with ITBIS/Subtotal keywords
- Camera preview frame must use `layoutSubviews()` override, not `UIScreen.main.bounds`
