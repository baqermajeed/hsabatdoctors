const fs = require('fs');
const path = require('path');

function createStore(dataFilePath) {
  const filePath = path.resolve(dataFilePath);
  const dir = path.dirname(filePath);

  if (!fs.existsSync(dir)) {
    fs.mkdirSync(dir, { recursive: true });
  }

  if (!fs.existsSync(filePath)) {
    fs.writeFileSync(
      filePath,
      JSON.stringify(
        {
          schemaVersion: 1,
          plans: [],
          doctorSelection: null,
          updatedAt: new Date().toISOString(),
        },
        null,
        2,
      ),
      'utf8',
    );
  }

  function normalizeState(parsed) {
    if (Array.isArray(parsed)) {
      // توافق مع الإصدارات القديمة التي تخزن plans كمصفوفة مباشرة.
      return {
        schemaVersion: 1,
        plans: parsed,
        doctorSelection: null,
        updatedAt: new Date().toISOString(),
      };
    }
    if (!parsed || typeof parsed !== 'object') {
      return {
        schemaVersion: 1,
        plans: [],
        doctorSelection: null,
        updatedAt: new Date().toISOString(),
      };
    }
    const plans = Array.isArray(parsed.plans) ? parsed.plans : [];
    const doctorSelection =
      parsed.doctorSelection && typeof parsed.doctorSelection === 'object'
        ? parsed.doctorSelection
        : null;
    return {
      schemaVersion: Number(parsed.schemaVersion) || 1,
      plans,
      doctorSelection,
      updatedAt: parsed.updatedAt || new Date().toISOString(),
    };
  }

  function readAll() {
    const raw = fs.readFileSync(filePath, 'utf8');
    if (!raw.trim()) {
      return [];
    }
    const parsed = JSON.parse(raw);
    return normalizeState(parsed).plans;
  }

  function readState() {
    const raw = fs.readFileSync(filePath, 'utf8');
    if (!raw.trim()) {
      return normalizeState(null);
    }
    const parsed = JSON.parse(raw);
    return normalizeState(parsed);
  }

  function writeAll(plans) {
    const current = readState();
    writeState({ ...current, plans });
  }

  function writeState(state) {
    const tmp = `${filePath}.tmp`;
    const normalized = normalizeState({
      ...state,
      updatedAt: new Date().toISOString(),
    });
    fs.writeFileSync(tmp, JSON.stringify(normalized, null, 2), 'utf8');
    fs.renameSync(tmp, filePath);
  }

  function list({ doctor } = {}) {
    const plans = readAll();
    if (!doctor || !String(doctor).trim()) {
      return plans;
    }
    const needle = String(doctor).trim();
    return plans.filter(
      (plan) => String(plan.treatmentDoctor || '').trim() === needle,
    );
  }

  function upsert(plan) {
    const plans = readAll();
    const paymentId = String(plan.paymentId || '').trim();
    if (!paymentId) {
      throw new Error('paymentId مطلوب');
    }

    const next = plans.filter(
      (item) => String(item.paymentId || '').trim() !== paymentId,
    );
    next.push({
      ...plan,
      paymentId,
      updatedAt: new Date().toISOString(),
    });
    writeAll(next);
    return next.find((item) => item.paymentId === paymentId);
  }

  function remove(paymentId) {
    const id = String(paymentId || '').trim();
    const plans = readAll();
    const next = plans.filter(
      (item) => String(item.paymentId || '').trim() !== id,
    );
    const removed = next.length !== plans.length;
    if (removed) {
      writeAll(next);
    }
    return removed;
  }

  function replaceAll(plans) {
    if (!Array.isArray(plans)) {
      throw new Error('plans يجب أن يكون مصفوفة');
    }
    const stamped = plans.map((plan) => {
      const paymentId = String(plan.paymentId || '').trim();
      if (!paymentId) {
        throw new Error('كل خطة تحتاج paymentId');
      }
      return {
        ...plan,
        paymentId,
        updatedAt: new Date().toISOString(),
      };
    });
    writeAll(stamped);
    return stamped;
  }

  function replaceAppState(appState) {
    if (!appState || typeof appState !== 'object') {
      throw new Error('app state غير صالح');
    }
    const plans = Array.isArray(appState.plans) ? appState.plans : null;
    if (!plans) {
      throw new Error('plans يجب أن يكون مصفوفة');
    }
    const stampedPlans = plans.map((plan) => {
      const paymentId = String(plan.paymentId || '').trim();
      if (!paymentId) {
        throw new Error('كل خطة تحتاج paymentId');
      }
      return {
        ...plan,
        paymentId,
        updatedAt: new Date().toISOString(),
      };
    });

    const doctorSelection =
      appState.doctorSelection && typeof appState.doctorSelection === 'object'
        ? appState.doctorSelection
        : null;

    const nextState = {
      schemaVersion: Number(appState.schemaVersion) || 1,
      plans: stampedPlans,
      doctorSelection,
      updatedAt: new Date().toISOString(),
    };
    writeState(nextState);
    return nextState;
  }

  return {
    list,
    upsert,
    remove,
    replaceAll,
    readAll,
    readState,
    replaceAppState,
  };
}

module.exports = { createStore };
