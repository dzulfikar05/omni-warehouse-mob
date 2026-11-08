/// Seluruh konstanta endpoint API WMS OmniWarehouse.
class ApiEndpoints {
  ApiEndpoints._();

  // AUTHENTICATION
  static const String verifyTenant = '/verify-tenant';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String profile = '/profile';

  // DASHBOARD
  static String dashboardSummary(String slug) => '/$slug/dashboard/summary';

  // INBOUND (PENERIMAAN BARANG)
  static String inboundList(String slug) => '/$slug/inbound/';
  static String inboundDetail(String slug, String code) =>
      '/$slug/inbound/manifests/$code';
  static String inboundCreate(String slug) => '/$slug/inbound/store';
  static String inboundAdhoc(String slug) => '/$slug/inbound/adhoc';
  static String inboundVerifyBarcode(String slug) => '/$slug/inbound/scan-item';
  static String inboundPutaway(String slug) => '/$slug/inbound/putaway';
  static String inboundCommit(String slug) => '/$slug/inbound/commit';
  static String inboundHold(String slug) => '/$slug/inbound/hold';
  static String inboundResume(String slug) => '/$slug/inbound/resume';
  static String inboundOptions(String slug) => '/$slug/inbound/options';
  // OUTBOUND (PENGIRIMAN BARANG)
  static String outboundList(String slug) => '/$slug/transactions/outbound';
  static String outboundDetail(String slug, String code) =>
      '/$slug/transactions/outbound/$code';
  static String outboundVerifyBarcode(String slug) =>
      '/$slug/transactions/outbound/verify-barcode';
  static String outboundPacking(String slug) =>
      '/$slug/transactions/outbound/packing';
  static String outboundCommit(String slug) =>
      '/$slug/transactions/outbound/commit';

  // STOCK TRANSFER (MUTASI RAK / GUDANG)
  static String transferList(String slug) =>
      '/$slug/transactions/stock-transfer';
  static String transferCreate(String slug) =>
      '/$slug/transactions/stock-transfer';

  // STOCK OPNAME (AUDIT FISIK)
  static String opnameActiveSession(String slug) =>
      '/$slug/stock-opname/active-session';
  static String opnameVerifyCount(String slug) =>
      '/$slug/stock-opname/verify-count';
  static String opnameExecute(String slug) =>
      '/$slug/stock-opname/execute-adjustment';

  // PRODUCT LOOKUP
  static String productLookup(String slug) => '/$slug/products/lookup';
}
