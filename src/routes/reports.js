const router = require('express').Router();
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');

router.use(protect);

// GET /api/reports/dashboard
router.get('/dashboard', async (req, res, next) => {
  try {
    const uid = req.user.id;
    const todayStart = new Date(); todayStart.setHours(0,0,0,0);
    const todayEnd   = new Date(); todayEnd.setHours(23,59,59,999);
    const monthStart = new Date(new Date().getFullYear(), new Date().getMonth(), 1);

    const [todaySales, monthSales, todayExp, monthExp, lowStock, pending] = await Promise.all([
      db(`SELECT
            COALESCE(SUM(grand_total),0)     AS sales,
            COUNT(*)                          AS count,
            COALESCE(SUM(grand_total - (
              SELECT COALESCE(SUM(si.purchase_price * si.quantity),0)
              FROM sale_items si WHERE si.sale_id = s.id
            )),0) AS profit
          FROM sales s
          WHERE user_id=$1 AND sale_date BETWEEN $2 AND $3`,
         [uid, todayStart, todayEnd]),

      db(`SELECT
            COALESCE(SUM(grand_total),0) AS sales,
            COUNT(*)                     AS count,
            COALESCE(SUM(grand_total - (
              SELECT COALESCE(SUM(si.purchase_price * si.quantity),0)
              FROM sale_items si WHERE si.sale_id = s.id
            )),0) AS profit
          FROM sales s
          WHERE user_id=$1 AND sale_date >= $2`,
         [uid, monthStart]),

      db(`SELECT COALESCE(SUM(amount),0) AS total FROM expenses
          WHERE user_id=$1 AND expense_date BETWEEN $2 AND $3`,
         [uid, todayStart, todayEnd]),

      db(`SELECT COALESCE(SUM(amount),0) AS total FROM expenses
          WHERE user_id=$1 AND expense_date >= $2`,
         [uid, monthStart]),

      db(`SELECT COUNT(*) FROM products
          WHERE user_id=$1 AND is_active=true AND quantity <= min_stock_level`,
         [uid]),

      db(`SELECT COALESCE(SUM(current_balance),0) AS total, COUNT(*) AS customers
          FROM customers WHERE user_id=$1 AND current_balance > 0`,
         [uid]),
    ]);

    const ts = todaySales.rows[0];
    const ms = monthSales.rows[0];
    const te = parseFloat(todayExp.rows[0].total);
    const me = parseFloat(monthExp.rows[0].total);

    res.json({
      success: true,
      data: {
        today: {
          sales: parseFloat(ts.sales), salesCount: parseInt(ts.count),
          profit: parseFloat(ts.profit) - te,
        },
        month: {
          sales: parseFloat(ms.sales), salesCount: parseInt(ms.count),
          profit: parseFloat(ms.profit) - me,
        },
        lowStockCount:    parseInt(lowStock.rows[0].count),
        pendingAmount:    parseFloat(pending.rows[0].total),
        pendingCustomers: parseInt(pending.rows[0].customers),
      },
    });
  } catch (err) { next(err); }
});

// GET /api/reports/sales-summary
router.get('/sales-summary', async (req, res, next) => {
  try {
    const { startDate, endDate, groupBy = 'day' } = req.query;
    const values = [req.user.id];
    let dateWhere = '';
    if (startDate) { values.push(startDate); dateWhere += ` AND sale_date >= $${values.length}`; }
    if (endDate)   { values.push(endDate);   dateWhere += ` AND sale_date <= $${values.length}`; }

    const trunc = groupBy === 'month' ? 'month' : groupBy === 'week' ? 'week' : 'day';

    const { rows } = await db(
      `SELECT
         DATE_TRUNC('${trunc}', sale_date) AS period,
         COALESCE(SUM(grand_total),0)      AS total_sales,
         COUNT(*)                           AS sales_count,
         COALESCE(SUM(grand_total - (
           SELECT COALESCE(SUM(si.purchase_price * si.quantity),0)
           FROM sale_items si WHERE si.sale_id = s.id
         )),0) AS total_profit
       FROM sales s
       WHERE user_id = $1 ${dateWhere}
       GROUP BY period
       ORDER BY period ASC`,
      values
    );
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

// GET /api/reports/top-products
router.get('/top-products', async (req, res, next) => {
  try {
    const { startDate, endDate, limit = 10 } = req.query;
    const values = [req.user.id];
    let dateWhere = '';
    if (startDate) { values.push(startDate); dateWhere += ` AND s.sale_date >= $${values.length}`; }
    if (endDate)   { values.push(endDate);   dateWhere += ` AND s.sale_date <= $${values.length}`; }
    values.push(limit);

    const { rows } = await db(
      `SELECT
         si.product_id,
         si.product_name,
         SUM(si.quantity)  AS total_qty,
         SUM(si.total)     AS total_revenue
       FROM sale_items si
       JOIN sales s ON s.id = si.sale_id
       WHERE s.user_id = $1 ${dateWhere}
       GROUP BY si.product_id, si.product_name
       ORDER BY total_revenue DESC
       LIMIT $${values.length}`,
      values
    );
    res.json({ success: true, data: rows });
  } catch (err) { next(err); }
});

// GET /api/reports/profit-loss
router.get('/profit-loss', async (req, res, next) => {
  try {
    const { startDate, endDate } = req.query;
    const values = [req.user.id];
    let dateFilter = '';
    if (startDate) { values.push(startDate); dateFilter += ` AND sale_date >= $${values.length}`; }
    if (endDate)   { values.push(endDate);   dateFilter += ` AND sale_date <= $${values.length}`; }

    const [salesRes, expensesRes] = await Promise.all([
      db(`SELECT
            COALESCE(SUM(grand_total),0) AS revenue,
            COALESCE(SUM((
              SELECT COALESCE(SUM(si.purchase_price * si.quantity),0)
              FROM sale_items si WHERE si.sale_id = s.id
            )),0) AS cost_of_goods
          FROM sales s WHERE user_id=$1 ${dateFilter}`,
         values),
      db(`SELECT COALESCE(SUM(amount),0) AS total_expenses
          FROM expenses WHERE user_id=$1`,
         [req.user.id]),
    ]);

    const revenue   = parseFloat(salesRes.rows[0].revenue);
    const cogs      = parseFloat(salesRes.rows[0].cost_of_goods);
    const expenses  = parseFloat(expensesRes.rows[0].total_expenses);
    const grossProfit = revenue - cogs;
    const netProfit   = grossProfit - expenses;

    res.json({
      success: true,
      data: { revenue, cogs, grossProfit, expenses, netProfit },
    });
  } catch (err) { next(err); }
});

module.exports = router;
