const router = require('express').Router();
const { query: db } = require('../config/database');
const { protect, adminOnly } = require('../middleware/auth');

// GET /api/version/check?platform=android&currentVersion=1.0.0
router.get('/check', async (req, res, next) => {
  try {
    const { platform, currentVersion } = req.query;
    const { rows } = await db(
      `SELECT * FROM app_versions
       WHERE platform IN ($1, 'all') AND is_active = true
       ORDER BY created_at DESC LIMIT 1`,
      [platform]
    );
    const parseV = (v = '0.0.0') => v.split('+')[0].split('.').map(Number);
    const compare = (a, b) => {
      const pa = parseV(a), pb = parseV(b);
      for (let i = 0; i < 3; i++) { if (pa[i] > pb[i]) return 1; if (pa[i] < pb[i]) return -1; }
      return 0;
    };

    const envVersion = process.env.CURRENT_APP_VERSION;
    const envDownloadUrl = platform === 'windows'
      ? (process.env.WIN_DOWNLOAD_URL || process.env.WINDOWS_DOWNLOAD_URL)
      : process.env.APK_DOWNLOAD_URL;
    const envReleaseNotes = process.env.RELEASE_NOTES;

    let latest = rows[0];
    if (envVersion && (!latest || compare(envVersion, latest.version) > 0)) {
      latest = {
        version: envVersion,
        download_url: envDownloadUrl,
        release_notes: envReleaseNotes,
        is_force_update: false,
      };
    }

    if (!latest) return res.json({ success: true, hasUpdate: false });

    const hasUpdate = compare(latest.version, currentVersion) > 0;
    res.json({
      success: true, hasUpdate,
      isForceUpdate: latest.is_force_update && hasUpdate,
      latestVersion: latest.version,
      downloadUrl: latest.download_url || envDownloadUrl,
      releaseNotes: latest.release_notes,
    });
  } catch (err) { next(err); }
});

// POST /api/version  (admin only)
router.post('/', protect, adminOnly, async (req, res, next) => {
  try {
    const { platform, version, minVersion, downloadUrl, releaseNotes, isForceUpdate } = req.body;
    const { rows } = await db(
      `INSERT INTO app_versions (platform, version, min_version, download_url, release_notes, is_force_update)
       VALUES ($1,$2,$3,$4,$5,$6) RETURNING *`,
      [platform, version, minVersion||null, downloadUrl||null, releaseNotes||null, isForceUpdate||false]
    );
    res.status(201).json({ success: true, data: rows[0] });
  } catch (err) { next(err); }
});

module.exports = router;
