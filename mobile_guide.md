# OmniWarehouse — Mobile App Project Guide
### Panduan Eksekusi untuk AI Agent

> **Konteks**: Dokumen ini adalah panduan pembangunan aplikasi mobile Flutter untuk sistem OmniWarehouse WMS (Warehouse Management System). Backend-nya adalah Laravel multi-tenant yang sudah berjalan di repo `dzulfikar05/omni-warehouse`. Mobile ini adalah repo **terpisah**. Dokumen ini harus menjadi satu-satunya referensi eksekusi.

---

## 1. Visi & Prinsip Utama

### 1.1 Mobile Bukan Versi Mini Web
Aplikasi web OmniWarehouse adalah **pusat manajemen** (inisiasi transaksi, data master, laporan). Aplikasi mobile ini adalah **alat eksekusi di lantai gudang** — dipakai oleh operator yang bergerak, bukan admin di meja.

```
WEB (Manager/Admin):        MOBILE (Operator Gudang):
────────────────────        ─────────────────────────
Inisiasi Manifest PO   →    Eksekusi bongkar muat fisik
Assign Dock Bay        →    Scan item satu per satu
Buat SO Outbound       →    Pick & konfirmasi per item
Buat Opname Session    →    Hitung fisik per rak
Lihat Report Detail    →    Dashboard ringkas hari ini
CRUD Master Data       →    (tidak ada di mobile)
Manage Users & Roles   →    (tidak ada di mobile)
```

### 1.2 Prinsip Desain
- **Task-first**: Operator masuk → langsung tau mau ngapain (Today's tasks)
- **Scan-centric**: Scanning adalah core interaction, bukan form typing
- **Offline-first**: Saat online, transaksi dikirim langsung ke API fitur terkait. Jika request gagal karena jaringan, perubahan disimpan lokal dan dapat dikirim ulang saat koneksi pulih.
- **Role-aware**: UI menyesuaikan role user (operator vs supervisor)
- **One-handed friendly**: CTA selalu di bawah, mudah dijangkau jempol

### 1.3 Target User
| Role | Akses |
|------|-------|
| **Warehouse Operator** | Dashboard, Inbound scan, Outbound scan, Stock Transfer scan, Stock Opname scan, Sync, Profile |
| **Supervisor/Manager** | Semua operator + melihat progress semua operator |

---

## 2. Technical Stack

```yaml
Framework: Flutter (Dart, minimum SDK 3.x)
State Management: Riverpod (flutter_riverpod + riverpod_annotation)
Navigation: go_router
HTTP Client: Dio + dio_smart_retry
Auth Storage: flutter_secure_storage
Offline DB: SQLite (sqflite mobile, sqflite_common_ffi desktop)
Barcode Scanner: mobile_scanner
Camera: camera (untuk foto bukti jika diperlukan)
Push Notif: firebase_messaging (opsional, fase 2)
Localization: intl
UI: Material 3 dengan override design system custom (bukan default Material)
Linting: very_good_analysis atau flutter_lints
```

> **Prinsip Stack**: Tidak over-engineered. Tidak perlu BLoC yang verbose. Riverpod sudah cukup clean dan testable. SQLite menyimpan antrean inbound dan cache master data per tenant/pengguna.

---

## 3. Arsitektur Kode — Feature-First Clean Architecture

### 3.1 Folder Structure

```
lib/
├── core/
│   ├── api/
│   │   ├── api_client.dart          ← Dio instance, interceptors, token refresh
│   │   ├── api_endpoints.dart       ← Semua URL constant
│   │   └── api_exception.dart       ← Custom exception classes
│   ├── auth/
│   │   ├── auth_state.dart          ← Auth state model
│   │   ├── auth_provider.dart       ← Riverpod auth notifier
│   │   └── secure_storage.dart      ← Token & tenant storage wrapper
│   ├── offline/
│   │   ├── offline_db.dart          ← SQLite init, master cache, dan antrean inbound
│   │   ├── sync_manager.dart        ← Queue & sync logic
│   │   └── offline_identity.dart   ← Scope antrean ke tenant/pengguna
│   ├── router/
│   │   └── app_router.dart          ← go_router config, guards, routes
│   └── theme/
│       ├── app_colors.dart          ← Design token warna (lihat Section 4)
│       ├── app_text_styles.dart     ← Typography tokens
│       ├── app_spacing.dart         ← Spacing tokens
│       └── app_theme.dart           ← MaterialTheme override
├── features/
│   ├── auth/
│   │   ├── data/
│   │   │   └── auth_repository.dart
│   │   ├── domain/
│   │   │   └── auth_model.dart
│   │   └── presentation/
│   │       ├── home_screen.dart     ← Welcome/landing page
│   │       ├── login_step1_screen.dart ← Input Tenant ID
│   │       └── login_step2_screen.dart ← Input Email + Password
│   ├── dashboard/
│   │   ├── data/
│   │   │   └── dashboard_repository.dart
│   │   ├── domain/
│   │   │   └── dashboard_model.dart ← KPI, today tasks model
│   │   └── presentation/
│   │       └── dashboard_screen.dart
│   ├── inbound/
│   │   ├── data/
│   │   │   └── inbound_repository.dart
│   │   ├── domain/
│   │   │   ├── inbound_model.dart   ← Manifest, InboundItem
│   │   │   └── inbound_offline.dart ← Model transaksi inbound offline
│   │   └── presentation/
│   │       ├── inbound_list_screen.dart
│   │       ├── inbound_form_screen.dart
│   │       └── inbound_scanner_screen.dart
│   ├── outbound/
│   │   ├── data/
│   │   │   └── outbound_repository.dart
│   │   ├── domain/
│   │   │   └── outbound_model.dart
│   │   └── presentation/
│   │       ├── outbound_list_screen.dart
│   │       ├── outbound_form_screen.dart
│   │       └── outbound_scanner_screen.dart
│   ├── stock_transfer/
│   │   ├── data/
│   │   │   └── transfer_repository.dart
│   │   ├── domain/
│   │   │   └── transfer_model.dart  ← SKU, from_location, to_location, qty
│   │   └── presentation/
│   │       ├── transfer_list_screen.dart
│   │       ├── transfer_form_screen.dart
│   │       └── transfer_scanner_screen.dart
│   ├── stock_opname/
│   │   ├── data/
│   │   │   └── opname_repository.dart
│   │   ├── domain/
│   │   │   ├── opname_model.dart    ← OpnameSession, ReconciliationItem
│   │   │   └── opname_offline.dart  ← Queue untuk offline counting
│   │   └── presentation/
│   │       ├── opname_list_screen.dart
│   │       └── opname_scanner_screen.dart
│   ├── scanner/
│   │   └── presentation/
│   │       └── generic_scanner_screen.dart ← Generic scan, auto-route by context
│   ├── sync/
│   │   └── presentation/
│   │       └── sync_screen.dart     ← List pending, tombol sync, log
│   └── profile/
│       ├── data/
│       │   └── profile_repository.dart
│       └── presentation/
│           ├── profile_screen.dart
│           └── edit_profile_screen.dart
├── shared/
│   ├── widgets/
│   │   ├── omni_app_bar.dart        ← Consistent top AppBar
│   │   ├── omni_bottom_nav.dart     ← Bottom navigation bar
│   │   ├── omni_button.dart         ← Primary & secondary button
│   │   ├── omni_card.dart           ← Card container
│   │   ├── omni_status_badge.dart   ← Status chips (RECEIVING, DRAFT, CLOSED)
│   │   ├── omni_scanner_overlay.dart ← Reusable camera scanner UI
│   │   ├── omni_empty_state.dart    ← Empty state widget
│   │   ├── omni_loading.dart        ← Loading states
│   │   └── omni_snackbar.dart       ← Toast/snackbar helper
│   └── utils/
│       ├── date_formatter.dart
│       ├── number_formatter.dart
│       └── connectivity_checker.dart
└── main.dart
```

### 3.2 Pola per Feature
Setiap feature mengikuti pola:
```
Repository (data source: API atau Isar)
    ↓
Provider/Notifier (Riverpod — business logic, state)
    ↓
Screen/Widget (UI only, tidak ada logic bisnis di sini)
```

### 3.3 Aturan Keras Arsitektur
- ❌ Jangan taruh logic bisnis di Widget/Screen
- ❌ Jangan direct Dio call dari Screen, selalu lewat Repository
- ❌ Jangan buat God Provider yang handle semua fitur
- ✅ Satu file = satu tanggung jawab
- ✅ Model domain terpisah dari model API response (gunakan `.fromJson()`)
- ✅ Semua error handling di Repository, bukan di Screen

---

## 4. Design System

### 4.1 Color Palette
> Diambil dari web `app.css` dan komponen yang ada, disesuaikan untuk mobile.

```dart
// lib/core/theme/app_colors.dart

class AppColors {
  // Primary — Blue (konsisten dengan web blue-600)
  static const Color primary         = Color(0xFF2563EB); // blue-600
  static const Color primaryDark     = Color(0xFF1D4ED8); // blue-700
  static const Color primaryLight    = Color(0xFFEFF6FF); // blue-50
  static const Color primaryBorder   = Color(0xFFBFDBFE); // blue-200

  // Success — Emerald (web emerald-600)
  static const Color success         = Color(0xFF059669);
  static const Color successLight    = Color(0xFFECFDF5);
  static const Color successBorder   = Color(0xFF6EE7B7);

  // Warning — Amber (web amber-600)
  static const Color warning         = Color(0xFFD97706);
  static const Color warningLight    = Color(0xFFFFFBEB);
  static const Color warningBorder   = Color(0xFFFDE68A);

  // Danger — Rose (web destructive)
  static const Color danger          = Color(0xFFE11D48);
  static const Color dangerLight     = Color(0xFFFFF1F2);
  static const Color dangerBorder    = Color(0xFFFDA4AF);

  // Neutral — Slate (web slate-*)
  static const Color textPrimary     = Color(0xFF0F172A); // slate-900
  static const Color textSecondary   = Color(0xFF475569); // slate-600
  static const Color textMuted       = Color(0xFF94A3B8); // slate-400
  static const Color border          = Color(0xFFE2E8F0); // slate-200
  static const Color borderStrong    = Color(0xFFCBD5E1); // slate-300
  static const Color surface         = Color(0xFFFFFFFF); // white
  static const Color surfaceAlt      = Color(0xFFF8FAFC); // slate-50
  static const Color background      = Color(0xFFF1F5F9); // slate-100 (page bg)

  // Dark mode equivalents (jika support dark mode nanti)
  static const Color surfaceDark     = Color(0xFF0F172A); // slate-900
  static const Color cardDark        = Color(0xFF1E293B); // slate-800
  static const Color borderDark      = Color(0xFF334155); // slate-700
}
```

### 4.2 Typography
```dart
// lib/core/theme/app_text_styles.dart
// Font: Inter (Google Fonts) — lebih readable di mobile dibanding Instrument Sans web

// Scale
// heading1: 24px, bold
// heading2: 20px, bold  
// heading3: 16px, semibold
// body:     14px, regular
// bodySmall: 12px, regular
// caption:  11px, regular/medium
// mono:     13px, monospace (JetBrains Mono / RobotoMono) — untuk kode PO, barcode

// Contoh:
static const TextStyle heading1 = TextStyle(
  fontSize: 24, fontWeight: FontWeight.w700, color: AppColors.textPrimary,
  letterSpacing: -0.5,
);
static const TextStyle mono = TextStyle(
  fontSize: 13, fontWeight: FontWeight.w700, 
  fontFamily: 'RobotoMono', color: AppColors.primary,
);
```

### 4.3 Spacing & Border Radius
```dart
// lib/core/theme/app_spacing.dart
// 4px grid system

static const double xs  = 4.0;
static const double sm  = 8.0;
static const double md  = 12.0;
static const double lg  = 16.0;
static const double xl  = 20.0;
static const double xxl = 24.0;

// Border Radius
static const double radiusSm  = 8.0;
static const double radiusMd  = 12.0;
static const double radiusLg  = 16.0;
static const double radiusXl  = 20.0;
static const double radiusFull = 999.0;
```

### 4.4 Aturan Visual
- **Semua card** punya `borderRadius: 16`, border `AppColors.border`, shadow tipis `BoxShadow(blurRadius: 4, color: Colors.black.withOpacity(0.04))`
- **Primary CTA button** selalu biru `AppColors.primary`, tinggi minimum `52px` (thumb-friendly), border radius `12px`
- **Status badge** punya warna sesuai tabel di Section 7
- **AppBar** putih/surface, tidak ada elevation besar, judul `heading3`
- **Bottom navigation** putih, item aktif berwarna `AppColors.primary`, tidak pakai label teks — gunakan icon saja kecuali scanner center

---

## 5. Navigasi — Bottom Navigation Bar

### 5.1 Struktur 5 Tab

```
┌─────────────────────────────────────────┐
│                                         │
│          [content area]                 │
│                                         │
├─────────────────────────────────────────┤
│  🏠    📦    ⬤ SCAN    🔄    👤        │
│  Home  Inbound         Sync  Profile    │
└─────────────────────────────────────────┘
```

| Tab | Icon | Label | Route |
|-----|------|-------|-------|
| 1 | `home_rounded` | Dashboard | `/dashboard` |
| 2 | `inbox_rounded` | Inbound | `/inbound` |
| 3 | **CENTER — Besar biru** | Scan | `/scanner` |
| 4 | `sync_rounded` | Sync | `/sync` |
| 5 | `person_rounded` | Profile | `/profile` |

### 5.2 Center Scanner Button
- Ukuran: `64x64px`, lingkaran penuh, `AppColors.primary`
- Icon: `qr_code_scanner` putih, `28px`
- Menonjol di atas bottom bar (floating style, `transform: translateY(-12px)`)
- Tap → masuk ke `GenericScannerScreen` yang auto-detect konteks

### 5.3 Kenapa Outbound Tidak di Tab?
Outbound diakses dari **Dashboard Today's Task card** atau dari **Inbound tab dengan mode toggle**. Bottom nav 5 tab sudah optimal untuk ergonomi — lebih dari itu terlalu crowded. Stock Transfer dan Stock Opname juga diakses dari dashboard card, bukan tab tersendiri.

### 5.4 Route Map Lengkap

```dart
// go_router routes:

/home                      ← Welcome landing (sebelum login)
/login/tenant              ← Step 1: input Tenant ID
/login/credentials         ← Step 2: email + password

/dashboard                 ← Main tab 1
/inbound                   ← Main tab 2 — list manifest
/inbound/:code             ← Detail/scanner manifest tertentu
/outbound                  ← Dari dashboard card
/outbound/:code
/transfer                  ← Dari dashboard card  
/transfer/form
/opname                    ← Dari dashboard card
/opname/:session_code
/scanner                   ← Main tab 3 — generic
/sync                      ← Main tab 4
/profile                   ← Main tab 5
/profile/edit
```

---

## 6. Auth Flow — Multi-Tenant Login

Sesuai arsitektur backend Laravel multi-tenant:

```
Step 1: User input Workspace Tenant ID (misal: "gudang-jaya")
  → POST /api/tenant/{tenant_id}/verify-tenant
  → Response: { valid: true, tenant_name: "Gudang Jaya", logo_url: "..." }
  → Tampilkan nama tenant sebagai konfirmasi visual

Step 2: User input Email + Password
  → POST /api/tenant/{tenant_id}/auth/login
  → Response: { token: "...", user: { name, role, permissions[] } }
  → Simpan: token di flutter_secure_storage
  → Simpan: tenant_slug, user_name, user_role, permissions di secure storage

Semua request API berikutnya:
  → Header: Authorization: Bearer {token}
  → URL prefix: /api/tenant/{tenant_slug}/...
```

### 6.1 Token Interceptor
Dio interceptor harus:
1. Auto-inject `Authorization: Bearer {token}` di setiap request
2. Jika response 401 → clear token → redirect ke `/login/tenant`
3. Jika response 422 → parse Laravel validation errors → tampilkan di form

### 6.2 Permission Guard
Route guard di `go_router` cek:
- Ada token? Kalau tidak → redirect `/home`
- Sudah di dalam app dan token expired? → silent refresh atau logout

---

## 7. Screen Inventory — Detail Per Screen

### 7.1 Home Screen (`/home`)
**Tampilan:**
- Background putih bersih
- Logo OmniWarehouse di tengah (diamond icon + teks "OmniWarehouse" + "Aplikasi Handheld WMS")
- Subtitle: "Operasi logistik multi-gudang yang tepat, akurat, dan offline-ready"
- 1 CTA button besar biru: "Masuk dengan Akun Operator →"

**Behavior:**
- Jika sudah ada token valid di storage → langsung redirect `/dashboard` (skip home)

---

### 7.2 Login Step 1 — Tenant ID (`/login/tenant`)
**Tampilan:**
- Logo kecil di atas
- Judul: "Login Operator Gudang"
- Field: "Workspace / Tenant ID" (text input, contoh placeholder: "gudang-jaya")
- Button: "Verifikasi Tenant →" (disabled saat loading)
- Loading state saat request

**Behavior:**
- Setelah verifikasi berhasil → tampilkan banner tenant name + logo
- Navigasi ke Step 2 dengan tenant_slug tersimpan di state

---

### 7.3 Login Step 2 — Credentials (`/login/credentials`)
**Tampilan:**
- Banner kecil: nama tenant yang sudah diverifikasi (misal: "✓ Gudang Jaya")
- Field: Email / Username
- Field: Password (dengan toggle show/hide)
- Button: "Masuk dengan Akun Operator →"
- Link kecil: "← Ganti Workspace"

**Error States:**
- 401: "Email atau password salah"
- 422: tampilkan error per field

---

### 7.4 Dashboard (`/dashboard`)
**Tampilan:**
- AppBar: Logo OmniWarehouse + nama user + avatar initials + indicator Online/Offline
- **Hero Card Biru**: "Scan Barcode → Mulai Transaksi" (shortcut ke Generic Scanner)
- **Sync Banner** (muncul jika ada data offline pending): "X berkas menunggu sync → [Sync Sekarang]"
- **Section "Tugas Hari Ini"**: 
  - Card Inbound: jumlah manifest aktif + progress bar + [Kelola →]
  - Card Outbound: jumlah SO aktif + progress + [Kelola →]
  - Card Stock Transfer: jumlah pending transfer + [Kelola →]
  - Card Stock Opname: session aktif + progress hitung fisik + [Kelola →]
- Card kosong jika tidak ada tugas hari ini

**State Models:**
```dart
class DashboardData {
  final bool isOnline;
  final int pendingSyncCount;
  final int activeInboundCount;
  final int activeOutboundCount;
  final int activeSTransferCount;
  final OpnameSummary? activeOpname;
}
```

---

### 7.5 Inbound — List (`/inbound`)
**Tampilan:**
- AppBar: "Inbound Management"; manifes dibuat di sistem upstream, bukan dari mobile
- Stats row: Total PO In | Receiving | Draft | Closed
- Search bar: cari PO, supplier, no polisi
- Filter chips: Semua | RECEIVING | DRAFT | CLOSED
- List card per manifest:
  - Kode manifest (mono font, biru)
  - Nama supplier + nama gudang
  - Progress bar: `good_units / total_po_units`
  - Status badge
  - Button: "Lokasi Scan PO →" atau "Lihat Detail"

**Status Badge Colors:**
| Status | Background | Text |
|--------|-----------|------|
| RECEIVING | `warningLight` | `warning` |
| DRAFT | `primaryLight` | `primary` |
| CLOSED | `successLight` | `success` |
| HOLD | `dangerLight` | `danger` |

---

### 7.6 Inbound — Scanner (`/inbound/:code`)
- Pilih manifes yang sudah ada, scan barcode/SKU, lalu simpan kuantitas baik/rusak dan rak putaway.
- Tidak ada pembuatan manifes inbound di mobile.
- Saat online, pembuatan manifes dan perubahan scan/putaway/commit dikirim langsung ke API inbound. Jika tidak ada koneksi, perubahan disimpan lokal per `manifest_code`; commit ditambahkan ke payload yang sama sebagai `should_commit`.

---

### 7.7 Outbound — List and Scanner
- Mobile hanya membuka manifes SO yang sudah ada; pembuatan manifes outbound tidak tersedia di mobile.
- Scan barcode/SKU dan simpan kuantitas picking, jumlah rusak, serta rak sumber. Pemilihan rak dilakukan setelah memilih gudang; stok SKU per rak hanya ditampilkan pada dropdown rak.
- Detail outbound harus mengirim `warehouse_id`, `warehouse_name`, dan `stock_by_sku` (map `sku_id` ke jumlah stok) pada setiap lokasi. Jumlah total stok lokasi tidak dapat menggantikan stok per SKU.
- Saat online, pembuatan manifes dan perubahan picking/commit dikirim langsung ke API outbound. Jika tidak ada koneksi, hasil picking disimpan lokal per `manifest_code`; commit disatukan dengan payload offline melalui `should_commit`.
- Status: PICKING | PACKING | DISPATCHED | HOLD

---

### 7.8 Stock Transfer (`/transfer`)
**List Screen:**
- Daftar transfer lokal dan status sinkronisasi; antrean tetap tersimpan sampai backend mengonfirmasi sukses

**Form Screen:**
- Muat SKU dan lokasi dari endpoint options; gunakan ID lokasi, bukan kode rak yang bisa ambigu
- Setiap item harus memiliki `sku_id`, `from_location_id`, `to_location_id`, dan `quantity` minimal 1
- Catatan, batch, dan tanggal kedaluwarsa bersifat opsional; backend tetap menentukan stok yang dipindahkan dengan FEFO

Transfer online langsung dikirim ke API. Jika koneksi tidak tersedia, transfer disimpan lokal dengan kode `TRF-YYYYMMDD-XXXX` dan UUID transaksi; retry memakai UUID yang sama dan respons `already_synced` menandakan retry idempoten. Error validasi tidak dimasukkan ke antrean offline.

---

### 7.9 Stock Opname (`/opname`)
**List Screen:**
- Tampilkan semua sesi dengan progress, status, gudang, lokasi/rak, auditor, dan waktu pembuatan
- Gunakan pagination backend dan buka detail sesi berdasarkan `session_id`
- Tidak ada endpoint pembuatan sesi; jangan membuat sesi lewat API

**Scanner Screen (Offline-first):**
- Tampilkan list item per rak yang perlu dihitung
- Scan atau ketik satu barcode/SKU → auto-match ke daftar item sesi
- Setelah SKU ditemukan, masukkan jumlah fisik total untuk SKU tersebut; tidak perlu scan satu barcode berulang kali untuk setiap unit
- Field jumlah otomatis memilih nilai hitungan terakhir agar mudah dikoreksi
- Blind count: jangan meminta atau menampilkan stok sistem maupun variance
- Gunakan `location_id` dan rak sebagai lingkup hitung; tampilkan `location_label` untuk informasi lokasi. `zone` hanya kompatibilitas sesi lama.
- Sesi yang terikat ke lokasi harus tetap dihitung pada `session.location_id`. Untuk sesi semua lokasi, setiap hitungan harus menyertakan lokasi dan rak.
- Sesi yang ditutup atau disesuaikan tidak menerima hitungan baru
- Saat online, hitungan dan submit review dikirim langsung ke endpoint masing-masing. Hanya jika request gagal karena jaringan, data disimpan lokal untuk dikirim ulang melalui antrean offline
- Progress bar: `X dari Y item terhitung`

**API yang tersedia (relatif terhadap prefix API):**
- `GET /{tenant_slug}/stock-opname` — daftar seluruh status dengan pagination
- `GET /{tenant_slug}/stock-opname/sessions/{session_id}` — detail sesi dan item
- `GET /{tenant_slug}/stock-opname/active` — sesi terbaru, atau sesi tertentu dengan query `session_id`; respons memuat `data.session` dan `data.items`
- `POST /{tenant_slug}/stock-opname/record-count` — hitung via `item_id` atau scan via identitas sesi dan `barcode`; mendukung `location_id` dan `target_rack`
- `POST /{tenant_slug}/stock-opname/sync-offline` — identitas sesi dan daftar item, masing-masing wajib memiliki `physical_qty`
- `POST /{tenant_slug}/stock-opname/submit-review` — identitas sesi berupa `session_id` atau `session_code`

Jangan mengarang endpoint daftar/buat sesi atau field payload. Tampilkan error validasi server, termasuk HTTP 422, kepada operator.

---

### 7.10 Generic Scanner (`/scanner` — center tab)
**Behavior:**
- Kamera aktif langsung
- Scan barcode apapun
- Sistem deteksi format:
  - Format PO Inbound (misal `PO-XXXX-XXXX`) → route ke inbound scanner
  - Format PO Outbound (misal `SO-XXXX-XXXX`) → route ke outbound scanner
  - Format SKU/Barcode produk → tampilkan product lookup card
- Product Lookup: nama produk, SKU code, stok per lokasi, batch info
- Berguna untuk operator yang ingin cek stok cepat

---

### 7.11 Sync Data (`/sync` — tab 4)
**Tampilan:**
- AppBar: "Sinkronisasi Data"
- Banner status: Online ✓ / Offline ✗
- Card summary: "X Berkas menunggu sync"
- Button besar: "Sync Sekarang" untuk mengirim seluruh antrean manual
- List inbound pending: nama transaksi + timestamp + jumlah data + status (pending/syncing/done/error)
- Link: "Hapus Log Sukses" (hapus log yang sudah berhasil)

**Offline Queue Logic:**
- Daftar inbound, outbound, transfer, dan sesi opname menyimpan respons API terakhir di SQLite per tenant, pengguna, dan filter; kegagalan jaringan menampilkan snapshot tersebut tanpa menghapus antrean lokal.
- Saat API dapat dijangkau, pembuatan inbound/outbound/transfer dan pencatatan hitungan opname dikirim langsung ke endpoint fitur, bukan melewati antrean sync. Antrean lokal hanya dipakai jika request gagal karena jaringan; pesan offline ditampilkan untuk transaksi yang benar-benar tertunda.
- Scan/putaway inbound dan picking/commit outbound untuk manifes yang sudah ada disimpan terlebih dahulu ke SQLite dan dikirim melalui endpoint `sync-offline` dengan `manifest_code`; commit menggunakan `should_commit`. Retry mempertahankan identitas queue yang sama.
- Pembuatan transfer dapat dilakukan offline; draft disimpan lokal dengan UUID transaksi yang stabil dan dikirim melalui endpoint `sync-offline`.
- Hitungan opname disimpan lokal per sesi saat offline lalu dikirim melalui endpoint `sync-offline`.
- Master supplier, SKU, dan rak di-cache secara terpisah untuk tenant dan pengguna aktif; antrean pengguna lain tidak ditampilkan atau dikirim.
- Mode default adalah manual: seluruh antrean inbound, outbound, transfer, dan opname dikirim melalui tombol "Sync Sekarang".
- Pengaturan Profil menyediakan toggle "Sinkronisasi Otomatis". Jika aktif, antrean dikirim ketika koneksi internet tersedia; jika dinyalakan saat online, antrean yang sudah ada langsung dicoba.
- Jika gagal → status `ERROR` dan pesan tersimpan; retry memakai ID lokal yang sama.
- Agar retry tidak membuat manifes duplikat, backend wajib memproses `local_uuid` secara idempoten dan menegakkan keunikan setidaknya pada scope tenant.
- Pilihan sinkronisasi otomatis tersimpan lokal dan mati secara default.

---

### 7.12 Profile (`/profile` — tab 5)
**Tampilan:**
- Avatar besar (initials atau foto)
- Nama user + tenant name
- Stats ringkas: Total Pengiriman diproses | SKU Entry | Shift aktif
- Button: "Edit Profile →"
- Toggle: "Sinkronisasi Otomatis" (mati secara default; antrean akan dikirim saat internet tersedia jika diaktifkan)
- Button: "Keluar (Logout)" — warna danger, konfirmasi dialog dulu

---

### 7.13 Edit Profile (`/profile/edit`)
**Form:**
- Nama Lengkap
- Email (read-only, tidak bisa diubah)
- No. WhatsApp / Kontak
- Simpan → PUT ke API profil user

---

## 8. Offline-First Strategy

### 8.1 Apa yang Harus Offline-Capable
| Fitur | Offline Mode |
|-------|-------------|
| Stock Opname counting | ✅ Wajib (scan & input qty ke Isar) |
| Inbound putaway confirmation | ✅ Queue ke Isar |
| Outbound pick confirmation | ✅ Queue ke Isar |
| Dashboard | ⚠️ Tampilkan data terakhir dari cache |
| Product Lookup | ⚠️ Cache data produk (TTL 1 jam) |
| Auth/Login | ❌ Harus online |

### 8.2 Sync Queue Model
```dart
// Isar model
@collection
class SyncQueueItem {
  Id id = Isar.autoIncrement;
  late String transactionType;   // 'inbound_putaway' | 'outbound_pick' | 'opname_count' | 'transfer'
  late String payload;           // JSON string
  late DateTime createdAt;
  late String status;            // 'PENDING' | 'SYNCING' | 'SUCCESS' | 'ERROR'
  String? errorMessage;
  int retryCount = 0;
}
```

### 8.3 Connectivity Detection
- Gunakan `connectivity_plus` package
- Saat status berubah OFFLINE → ONLINE → trigger SyncManager
- SyncManager process queue FIFO, max 3 retry per item

---

## 9. Koneksi Backend Laravel

### 9.1 Base URL
```
BASE_URL = https://{domain}/api/tenant/{tenant_slug}
```

### 9.2 Endpoint Reference (yang dibutuhkan mobile)

```
AUTH:
POST  /api/tenant/{slug}/verify-tenant        ← verifikasi tenant ada
POST  /api/tenant/{slug}/auth/login           ← login, dapat token
POST  /api/tenant/{slug}/auth/logout          ← logout

DASHBOARD:
GET   /api/tenant/{slug}/dashboard/summary    ← KPI harian

INBOUND:
GET   /api/tenant/{slug}/transactions/inbound            ← list manifests
GET   /api/tenant/{slug}/transactions/inbound/{code}     ← detail + items
POST  /api/tenant/{slug}/transactions/inbound/verify-barcode
POST  /api/tenant/{slug}/transactions/inbound/putaway    ← update good/damaged/rack
POST  /api/tenant/{slug}/transactions/inbound/commit     ← finalize inbound

OUTBOUND:
GET   /api/tenant/{slug}/transactions/outbound
GET   /api/tenant/{slug}/transactions/outbound/{code}
POST  /api/tenant/{slug}/transactions/outbound/verify-barcode
POST  /api/tenant/{slug}/transactions/outbound/packing
POST  /api/tenant/{slug}/transactions/outbound/commit

STOCK TRANSFER:
GET   /{tenant_slug}/stock-transfer/options
POST  /{tenant_slug}/stock-transfer/sync-offline

STOCK OPNAME:
GET   /{tenant_slug}/stock-opname
GET   /{tenant_slug}/stock-opname/sessions/{session_id}
GET   /{tenant_slug}/stock-opname/active
POST  /{tenant_slug}/stock-opname/record-count
POST  /{tenant_slug}/stock-opname/sync-offline
POST  /{tenant_slug}/stock-opname/submit-review

PRODUCT LOOKUP:
GET   /api/tenant/{slug}/products/lookup?barcode={barcode}

PROFILE:
GET   /api/tenant/{slug}/profile
PUT   /api/tenant/{slug}/profile
```

> **Catatan**: Ikuti kontrak API backend yang tersedia. Jangan membuat endpoint atau payload baru untuk menutup endpoint yang belum tersedia.

### 9.3 Mock Data untuk Development
Saat API belum ada, semua repository gunakan **hardcoded mock data** dengan interface yang sudah siap diganti real API. Gunakan pola:

```dart
abstract class InboundRepository {
  Future<List<InboundManifest>> getManifests();
  Future<InboundManifest> getManifestDetail(String code);
  Future<void> submitPutaway(PutawayRequest req);
}

class MockInboundRepository implements InboundRepository {
  // hardcoded dummy data
}

class ApiInboundRepository implements InboundRepository {
  final Dio dio;
  // real API calls
}
```

Provider di Riverpod:
```dart
final inboundRepositoryProvider = Provider<InboundRepository>(
  (ref) => MockInboundRepository(), // ganti ke ApiInboundRepository nanti
);
```

---

## 10. Aturan UX & Interaksi

### 10.1 Loading States
- Setiap async action punya loading state → tampilkan `OmniLoading` widget atau shimmer
- Tidak ada blank screen tanpa loading indicator

### 10.2 Error Handling
- Error jaringan → `OmniSnackbar.error("Koneksi gagal. Data disimpan offline.")`
- Error validasi → inline error di bawah form field
- Error 500 → "Terjadi kesalahan server. Coba lagi."
- Jangan pernah crash app karena unhandled error

### 10.3 Konfirmasi Destruktif
- Logout → BottomSheet konfirmasi
- Commit Inbound/Outbound → AlertDialog: "Pastikan fisik barang sudah diverifikasi"
- Hapus log sync → Dialog konfirmasi

### 10.4 Feedback Haptic
- Scan berhasil → `HapticFeedback.mediumImpact()`
- Error/not found → `HapticFeedback.vibrate()`
- Commit sukses → `HapticFeedback.heavyImpact()`

### 10.5 Accessibility
- Semua CTA button minimum `48x48px` tap target
- Color tidak menjadi satu-satunya indikator status (selalu ada teks/ikon juga)
- Font minimum `12px` untuk teks kecil

---

## 11. Splash Screen

Buat **native splash screen** (menggunakan `flutter_native_splash`):
- Background: `#FFFFFF` (putih)
- Logo: icon diamond OmniWarehouse di tengah
- Warna logo: `#2563EB` (primary blue)

Setelah splash → check token di secure storage:
- Ada token valid → `/dashboard`
- Tidak ada → `/home`

---

## 12. Scope & Batasan Tegas

### ✅ Ada di Mobile
- Auth (multi-step tenant + credentials)
- Dashboard (today's tasks, KPI ringkas)
- Inbound execution (list, scanner, putaway, commit)
- Outbound execution (list, scanner, pick, commit)
- Stock Transfer (list, form, scanner single-item)
- Stock Opname (list session, scanner count, offline-first)
- Generic Scanner (product lookup)
- Sync Data (offline queue management)
- Profile (view & edit)

### ❌ Tidak Ada di Mobile
- CRUD Categories, Products, SKUs, Units (master data)
- CRUD Warehouses & Locations
- User & Roles management
- Reports detail (Stock Summary, Valuation, Movement)
- Company Profile settings
- Plans & Subscriptions
- Buat Manifest PO/SO baru (inisiasi dari web, eksekusi dari mobile)
- Export data (PDF/Excel)

---

## 13. Checklist Sebelum Mulai Coding

- [ ] Buat repo Flutter baru: `omni-warehouse-mobile`
- [ ] Setup `pubspec.yaml` dengan semua dependencies
- [ ] Buat folder structure sesuai Section 3
- [ ] Implementasi `core/theme/` (colors, text styles, spacing)
- [ ] Implementasi `core/router/app_router.dart`
- [ ] Implementasi `shared/widgets/` (AppBar, BottomNav, Button, Card, dll)
- [ ] Buat semua Mock Repositories
- [ ] Build semua screen dengan mock data
- [ ] Implement scanner overlay (reusable)
- [x] Implement SQLite queue/cache inbound + SyncManager manual/otomatis
- [ ] Integrasikan offline sync outbound, opname, dan transfer
- [ ] Native splash screen
- [ ] Pastikan bisa build di Android (iOS opsional)

---

*Guide ini adalah living document. Update saat ada keputusan arsitektur baru.*
*Dibuat berdasarkan analisis mendalam repo `dzulfikar05/omni-warehouse` dan diskusi desain bersama.*
