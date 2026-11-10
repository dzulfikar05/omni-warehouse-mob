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
  static String inboundVerifyBarcode(String slug) => '/$slug/inbound/scan-item';
  static String inboundPutaway(String slug) => '/$slug/inbound/putaway';
  static String inboundCommit(String slug) => '/$slug/inbound/commit';
  static String inboundHold(String slug) => '/$slug/inbound/hold';
  static String inboundResume(String slug) => '/$slug/inbound/resume';
  static String inboundOptions(String slug) => '/$slug/inbound/options';
  // OUTBOUND (PENGIRIMAN BARANG)
  static String outboundList(String slug) => '/$slug/outbound/';
  static String outboundDetail(String slug, String code) =>
      '/$slug/outbound/manifests/$code';
  static String outboundCreate(String slug) => '/$slug/outbound/store';
  static String outboundOptions(String slug) => '/$slug/outbound/options';
  static String outboundVerifyBarcode(String slug) =>
      '/$slug/outbound/verify-barcode';
  static String outboundPicking(String slug) => '/$slug/outbound/picking';
  static String outboundCommit(String slug) => '/$slug/outbound/commit';
  static String outboundHold(String slug) => '/$slug/outbound/hold';
  static String outboundResume(String slug) => '/$slug/outbound/resume';

  // STOCK TRANSFER (MUTASI RAK / GUDANG)
  static String transferList(String slug) => '/$slug/stock-transfer/';
  static String transferCreate(String slug) => '/$slug/stock-transfer/store';
  static String transferOptions(String slug) => '/$slug/stock-transfer/options';
  static String transferUpdate(String slug, String code) =>
      '/$slug/stock-transfer/$code';
  static String transferCancel(String slug, String code) =>
      '/$slug/stock-transfer/$code/cancel';

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
