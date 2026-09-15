# hsabat-plans-api

API مستقل لتخزين **خطط أقساط الرافدين** على VPS — بدون أي اتصال بقاعدة Xanthus SQL.

## المتطلبات

- Node.js 18+
- منفذ مفتوح (افتراضي `8787`) أو خلف Nginx مع HTTPS

## التثبيت على السيرفر

```bash
cd backend
cp .env.example .env
nano .env   # غيّر API_KEY إلى سر طويل
npm install
npm start
```

تشغيل دائم مع PM2:

```bash
npm install -g pm2
pm2 start src/server.js --name hsabat-plans
pm2 save
pm2 startup
```

## متغيرات البيئة

| المتغير | الوصف |
|---------|--------|
| `PORT` | منفذ الاستماع (افتراضي 8787) |
| `API_KEY` | مفتاح يرسله التطبيق في الهيدر `x-api-key` |
| `DATA_FILE` | مسار ملف JSON للتخزين |

## الـ Endpoints

| Method | Path | ملاحظة |
|--------|------|--------|
| GET | `/health` | بدون مفتاح — فحص الخدمة |
| GET | `/api/plans` | كل الخطط أو `?doctor=اسم` (للاستعادة) |
| GET | `/api/plans/:paymentId` | خطة واحدة |
| POST | `/api/plans` | حفظ/تحديث خطة واحدة |
| PUT | `/api/backup/plans` | باك أب كامل يستبدل كل الخطط |
| GET | `/api/backup/app-state` | جلب نسخة شاملة (خطط + إعدادات محاسبية) |
| PUT | `/api/backup/app-state` | حفظ نسخة شاملة (خطط + إعدادات محاسبية) |
| PUT | `/api/plans/:paymentId` | تحديث |
| DELETE | `/api/plans/:paymentId` | حذف |

### نموذج الاستخدام مع التطبيق

- التطبيق يخزّن الخطط **محلياً** للسرعة.
- يرفع باك أب للسيرفر يومياً (أو يدوياً من الإعدادات).
- النسخة الشاملة تشمل:
  - `plans`: كل خطط الأقساط (بما فيها localOnly)
  - `doctorSelection`: الأطباء المختارون + طبيب المالك + إجمالي التمويل
- بعد حذف التطبيق: **استعادة من السيرفر** تعيد الخطط للمحلي.

كل مسارات `/api/*` تحتاج الهيدر:

```http
x-api-key: YOUR_SECRET
```

### مثال جسم الخطة (POST)

```json
{
  "paymentId": "12345",
  "invoiceId": "9001",
  "patientName": "أحمد",
  "phoneNumber": "07xxxxxxxx",
  "treatmentDoctor": "د. فلان",
  "originalAmount": 1200000,
  "sourcePaymentDate": "2026-01-15T00:00:00.000",
  "months": 6,
  "startDate": "2026-02-01T00:00:00.000",
  "monthlyAmount": 200000
}
```

## Nginx (اختياري + HTTPS)

```nginx
server {
  listen 443 ssl;
  server_name plans.example.com;

  location / {
    proxy_pass http://127.0.0.1:8787;
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
  }
}
```

## التطبيق Flutter

من **الإعدادات** أدخل:

- عنوان الـ API مثل: `https://plans.example.com` أو `http://IP:8787`
- نفس قيمة `API_KEY`

ثم:

1. **تفعيل رفع يومي تلقائي** — يسجّل مهمة Windows تعمل كل يوم 02:00 حتى لو التطبيق مغلق
2. **رفع باك أب الآن** — يرسل كل الخطط المحلية للسيرفر فوراً
3. **استعادة من السيرفر** — بعد إعادة التنصيب فقط عند الحاجة
4. أثناء فتح التطبيق: إعادة محاولة كل 30 دقيقة إن حان موعد الباك أب

### ملاحظة الدومين لاحقاً

بعد ربط دومين ورفع الـ API على الـ VPS، ضع في التطبيق عنواناً مثل:

`https://plans.yourdomain.com`

بدل `http://IP:8787` — بدون تغيير منطق التطبيق.
