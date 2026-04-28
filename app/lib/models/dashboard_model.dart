class DashboardModel {
  final double todaySales;
  final int todaySalesCount;
  final double todayProfit;
  final double monthSales;
  final int monthSalesCount;
  final double monthProfit;
  final int lowStockCount;
  final double pendingAmount;
  final int pendingCustomers;

  const DashboardModel({
    this.todaySales = 0,
    this.todaySalesCount = 0,
    this.todayProfit = 0,
    this.monthSales = 0,
    this.monthSalesCount = 0,
    this.monthProfit = 0,
    this.lowStockCount = 0,
    this.pendingAmount = 0,
    this.pendingCustomers = 0,
  });

  factory DashboardModel.fromJson(Map<String, dynamic> j) {
    final today = j['today'] ?? {};
    final month = j['month'] ?? {};
    return DashboardModel(
      todaySales: (today['sales'] ?? 0).toDouble(),
      todaySalesCount: (today['salesCount'] ?? 0).toInt(),
      todayProfit: (today['profit'] ?? 0).toDouble(),
      monthSales: (month['sales'] ?? 0).toDouble(),
      monthSalesCount: (month['salesCount'] ?? 0).toInt(),
      monthProfit: (month['profit'] ?? 0).toDouble(),
      lowStockCount: (j['lowStockCount'] ?? 0).toInt(),
      pendingAmount: (j['pendingAmount'] ?? 0).toDouble(),
      pendingCustomers: (j['pendingCustomers'] ?? 0).toInt(),
    );
  }
}
