require('dotenv').config();

const express = require('express');
const cors = require('cors');
const morgan = require('morgan');
const { createStore } = require('./store');

const PORT = Number(process.env.PORT || 8787);
const API_KEY = String(process.env.API_KEY || '').trim();
const DATA_FILE = process.env.DATA_FILE || './data/plans.json';

if (!API_KEY) {
  console.error('يجب تعيين API_KEY في ملف .env');
  process.exit(1);
}

const store = createStore(DATA_FILE);
const app = express();

app.use(cors());
app.use(express.json({ limit: '2mb' }));
app.use(morgan('tiny'));

function requireApiKey(req, res, next) {
  const header = req.header('x-api-key') || '';
  const auth = req.header('authorization') || '';
  const bearer = auth.toLowerCase().startsWith('bearer ')
    ? auth.slice(7).trim()
    : '';
  const provided = (header || bearer).trim();

  if (!provided || provided !== API_KEY) {
    return res.status(401).json({ error: 'غير مصرح — مفتاح API غير صحيح' });
  }
  return next();
}

function validatePlan(body) {
  if (!body || typeof body !== 'object') {
    return 'جسم الطلب غير صالح';
  }
  const paymentId = String(body.paymentId || '').trim();
  if (!paymentId) {
    return 'paymentId مطلوب';
  }
  const months = Number(body.months);
  if (!Number.isFinite(months) || months < 1) {
    return 'months يجب أن يكون رقماً >= 1';
  }
  return null;
}

function validateDoctorSelection(body) {
  if (body == null) {
    return null;
  }
  if (typeof body !== 'object') {
    return 'doctorSelection يجب أن يكون كائن';
  }
  const selected = body.selectedDoctors;
  if (selected != null && !Array.isArray(selected)) {
    return 'selectedDoctors يجب أن تكون مصفوفة';
  }
  const total = body.totalTamweel;
  if (total != null && !Number.isFinite(Number(total))) {
    return 'totalTamweel يجب أن يكون رقم';
  }
  return null;
}

app.get('/health', (_req, res) => {
  const state = store.readState();
  res.json({
    ok: true,
    service: 'hsabat-plans-api',
    plans: state.plans.length,
    schemaVersion: state.schemaVersion || 1,
  });
});

app.get('/api/plans', requireApiKey, (req, res) => {
  const doctor = req.query.doctor;
  res.json({ plans: store.list({ doctor }) });
});

/// نسخة احتياطية كاملة تستبدل كل الخطط على السيرفر.
app.put('/api/backup/plans', requireApiKey, (req, res) => {
  const plans = req.body?.plans;
  if (!Array.isArray(plans)) {
    return res.status(400).json({ error: 'plans يجب أن يكون مصفوفة' });
  }
  for (const plan of plans) {
    const error = validatePlan(plan);
    if (error) {
      return res.status(400).json({ error });
    }
  }
  try {
    const saved = store.replaceAll(plans);
    return res.json({
      ok: true,
      count: saved.length,
      backedUpAt: new Date().toISOString(),
    });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'فشل رفع النسخة' });
  }
});

/// نسخة احتياطية شاملة للتطبيق (خطط + إعدادات محاسبية محلية).
app.put('/api/backup/app-state', requireApiKey, (req, res) => {
  const plans = req.body?.plans;
  if (!Array.isArray(plans)) {
    return res.status(400).json({ error: 'plans يجب أن يكون مصفوفة' });
  }
  for (const plan of plans) {
    const error = validatePlan(plan);
    if (error) {
      return res.status(400).json({ error });
    }
  }
  const doctorSelectionError = validateDoctorSelection(req.body?.doctorSelection);
  if (doctorSelectionError) {
    return res.status(400).json({ error: doctorSelectionError });
  }
  try {
    const saved = store.replaceAppState({
      schemaVersion: Number(req.body?.schemaVersion) || 1,
      plans,
      doctorSelection: req.body?.doctorSelection ?? null,
    });
    return res.json({
      ok: true,
      schemaVersion: saved.schemaVersion || 1,
      plansCount: saved.plans.length,
      backedUpAt: saved.updatedAt || new Date().toISOString(),
    });
  } catch (err) {
    return res
      .status(400)
      .json({ error: err.message || 'فشل حفظ النسخة الشاملة' });
  }
});

app.get('/api/backup/app-state', requireApiKey, (_req, res) => {
  const state = store.readState();
  return res.json({
    schemaVersion: Number(state.schemaVersion) || 1,
    plans: Array.isArray(state.plans) ? state.plans : [],
    doctorSelection:
      state.doctorSelection && typeof state.doctorSelection === 'object'
        ? state.doctorSelection
        : null,
    backedUpAt: state.updatedAt || null,
  });
});

app.get('/api/plans/:paymentId', requireApiKey, (req, res) => {
  const paymentId = String(req.params.paymentId || '').trim();
  const plan = store
    .readAll()
    .find((item) => String(item.paymentId || '').trim() === paymentId);
  if (!plan) {
    return res.status(404).json({ error: 'الخطة غير موجودة' });
  }
  return res.json({ plan });
});

app.post('/api/plans', requireApiKey, (req, res) => {
  const error = validatePlan(req.body);
  if (error) {
    return res.status(400).json({ error });
  }
  try {
    const plan = store.upsert(req.body);
    return res.status(201).json({ plan });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'فشل الحفظ' });
  }
});

app.put('/api/plans/:paymentId', requireApiKey, (req, res) => {
  const paymentId = String(req.params.paymentId || '').trim();
  const body = { ...req.body, paymentId };
  const error = validatePlan(body);
  if (error) {
    return res.status(400).json({ error });
  }
  try {
    const plan = store.upsert(body);
    return res.json({ plan });
  } catch (err) {
    return res.status(400).json({ error: err.message || 'فشل التحديث' });
  }
});

app.delete('/api/plans/:paymentId', requireApiKey, (req, res) => {
  const removed = store.remove(req.params.paymentId);
  if (!removed) {
    return res.status(404).json({ error: 'الخطة غير موجودة' });
  }
  return res.json({ ok: true });
});

app.use((err, _req, res, _next) => {
  console.error(err);
  res.status(500).json({ error: 'خطأ داخلي في الخادم' });
});

app.listen(PORT, '0.0.0.0', () => {
  console.log(`hsabat-plans-api يعمل على المنفذ ${PORT}`);
  console.log(`ملف البيانات: ${DATA_FILE}`);
});
