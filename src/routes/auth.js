const router  = require('express').Router();
const bcrypt  = require('bcryptjs');
const jwt     = require('jsonwebtoken');
const { body, validationResult } = require('express-validator');
const { query: db } = require('../config/database');
const { protect } = require('../middleware/auth');

const signToken = (user) => jwt.sign(
  { id: user.id, email: user.email, role: user.role },
  process.env.JWT_SECRET,
  { expiresIn: process.env.JWT_EXPIRE || '7d' }
);

const safeUser = (u) => ({
  id: u.id, name: u.name, email: u.email, role: u.role,
  shopName: u.shop_name, phone: u.phone, address: u.address,
});

// POST /api/auth/register
router.post('/register', [
  body('name').notEmpty().trim(),
  body('email').isEmail().normalizeEmail(),
  body('password').isLength({ min: 6 }),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, errors: errors.array() });
  try {
    const { name, email, password, shopName = 'My Shop', phone, address } = req.body;
    const exists = await db('SELECT id FROM users WHERE email = $1', [email]);
    if (exists.rows.length) return res.status(400).json({ success: false, message: 'Email already registered' });

    const hashed = await bcrypt.hash(password, 12);
    const result = await db(
      `INSERT INTO users (name, email, password, shop_name, phone, address)
       VALUES ($1, $2, $3, $4, $5, $6) RETURNING *`,
      [name, email, hashed, shopName, phone || null, address || null]
    );
    const user = result.rows[0];
    res.status(201).json({ success: true, token: signToken(user), user: safeUser(user) });
  } catch (err) { next(err); }
});

// POST /api/auth/login
router.post('/login', [
  body('email').isEmail().normalizeEmail(),
  body('password').notEmpty(),
], async (req, res, next) => {
  const errors = validationResult(req);
  if (!errors.isEmpty()) return res.status(400).json({ success: false, message: 'Invalid credentials' });
  try {
    const { email, password } = req.body;
    const result = await db('SELECT * FROM users WHERE email = $1', [email]);
    const user = result.rows[0];
    if (!user || !(await bcrypt.compare(password, user.password)))
      return res.status(401).json({ success: false, message: 'Invalid email or password' });
    if (!user.is_active)
      return res.status(403).json({ success: false, message: 'Account disabled' });
    await db('UPDATE users SET last_login = NOW() WHERE id = $1', [user.id]);
    res.json({ success: true, token: signToken(user), user: safeUser(user) });
  } catch (err) { next(err); }
});

// GET /api/auth/me
router.get('/me', protect, async (req, res, next) => {
  try {
    const { rows } = await db('SELECT * FROM users WHERE id = $1', [req.user.id]);
    if (!rows[0]) return res.status(404).json({ success: false, message: 'User not found' });
    res.json({ success: true, user: safeUser(rows[0]) });
  } catch (err) { next(err); }
});

// PUT /api/auth/profile
router.put('/profile', protect, async (req, res, next) => {
  try {
    const { name, shopName, phone, address } = req.body;
    const { rows } = await db(
      `UPDATE users SET name = COALESCE($1, name), shop_name = COALESCE($2, shop_name),
       phone = COALESCE($3, phone), address = COALESCE($4, address)
       WHERE id = $5 RETURNING *`,
      [name, shopName, phone, address, req.user.id]
    );
    res.json({ success: true, user: safeUser(rows[0]) });
  } catch (err) { next(err); }
});

// PUT /api/auth/change-password
router.put('/change-password', protect, [
  body('currentPassword').notEmpty(),
  body('newPassword').isLength({ min: 6 }),
], async (req, res, next) => {
  try {
    const { rows } = await db('SELECT password FROM users WHERE id = $1', [req.user.id]);
    if (!(await bcrypt.compare(req.body.currentPassword, rows[0].password)))
      return res.status(400).json({ success: false, message: 'Current password incorrect' });
    const hashed = await bcrypt.hash(req.body.newPassword, 12);
    await db('UPDATE users SET password = $1 WHERE id = $2', [hashed, req.user.id]);
    res.json({ success: true, message: 'Password updated' });
  } catch (err) { next(err); }
});

module.exports = router;
