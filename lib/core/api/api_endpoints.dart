/// Seluruh konstanta endpoint API WMS (Flat Route tanpa /v1).
class ApiEndpoints {
  ApiEndpoints._();

  // AUTHENTICATION
  static const String verifyTenant = '/verify-tenant';
  static const String login = '/auth/login';
  static const String logout = '/auth/logout';
  static const String profile = '/profile';

  // DASHBOARD
  static const String dashboardSummary = '/dashboard/summary';

  // INBOUND (PENERIMAAN BARANG)
  static const String inboundList = '/transactions/inbound';
  static String inboundDetail(String code) => '/transactions/inbound/$code';
  static const String inboundVerifyBarcode = '/transactions/inbound/verify-barcode';
  static const String inboundPutaway = '/transactions/inbound/putaway';
  static const String inboundCommit = '/transactions/inbound/commit';
  static const String inboundHold = '/transactions/inbound/hold';

  // OUTBOUND (PENGIRIMAN BARANG)
  static const String outboundList = '/transactions/outbound';
  static String outboundDetail(String code) => '/transactions/outbound/$code';
  static const String outboundVerifyBarcode = '/transactions/outbound/verify-barcode';
  static const String outboundPacking = '/transactions/outbound/packing';
  static const String outboundCommit = '/transactions/outbound/commit';
  static const String outboundHold = '/transactions/outbound/hold';

  // STOCK TRANSFER (MUTASI RAK / GUDANG)
  static const String transferList = '/transactions/stock-transfer';
  static const String transferCreate = '/transactions/stock-transfer';

  // STOCK OPNAME (AUDIT FISIK)
  static const String opnameActiveSession = '/stock-opname/active-session';
  static const String opnameVerifyCount = '/stock-opname/verify-count';
  static const String opnameExecute = '/stock-opname/execute-adjustment';

  // PRODUCT LOOKUP
  static const String productLookup = '/products/lookup';

}