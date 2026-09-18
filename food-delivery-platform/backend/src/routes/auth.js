const express = require("express");
const jwt = require("jsonwebtoken");
const https = require("https");
const router = express.Router();
const store = require("../services/mockStore");

const JWT_SECRET = process.env.JWT_SECRET || "gofresh-secret-2024";
const FAST2SMS_KEY = process.env.FAST2SMS_API_KEY || "";

const generateToken = (user) =>
  jwt.sign({ id: user._id, role: user.role, phone: user.phone }, JWT_SECRET, { expiresIn: "30d" });

// Send OTP via Fast2SMS
async function sendSMSOTP(phone, otp) {
  if (!FAST2SMS_KEY) {
    console.log(`\n📱 [DEV MODE] OTP for ${phone}: ${otp}\n`);
    return { success: true, dev: true };
  }

  return new Promise((resolve) => {
    const postData = JSON.stringify({
      route: "otp",
      variables_values: otp,
      numbers: phone,
      flash: 0
    });

    const options = {
      hostname: "www.fast2sms.com",
      path: "/dev/bulkV2",
      method: "POST",
      headers: {
        authorization: FAST2SMS_KEY,
        "Content-Type": "application/json",
        "Content-Length": Buffer.byteLength(postData)
      }
    };

    const req = https.request(options, (res) => {
      let data = "";
      res.on("data", (chunk) => { data += chunk; });
      res.on("end", () => {
        try {
          const parsed = JSON.parse(data);
          console.log(`📱 SMS sent to ${phone}:`, parsed);
          resolve({ success: parsed.return === true });
        } catch (e) {
          resolve({ success: false, error: e.message });
        }
      });
    });

    req.on("error", (e) => {
      console.error("Fast2SMS error:", e.message);
      resolve({ success: false, error: e.message });
    });

    req.write(postData);
    req.end();
  });
}

// ── Send OTP ─────────────────────────────────────────────────
router.post("/send-otp", async (req, res) => {
  const { phone } = req.body;
  if (!phone || phone.length < 10) return res.status(400).json({ error: "Valid phone number required" });

  // Check if user is suspended
  const existingUser = store.findUser({ phone });
  if (existingUser?.isSuspended) return res.status(403).json({ error: "Account suspended. Contact support." });

  const otp = store.generateOTP();
  store.data.otpStore[phone] = { otp, expiry: Date.now() + 5 * 60000 };

  const smsResult = await sendSMSOTP(phone, otp);
  console.log(`OTP for ${phone}: ${otp}`);

  res.json({
    success: true,
    message: FAST2SMS_KEY ? "OTP sent via SMS" : "OTP sent (dev mode - check server logs)",
    ...(FAST2SMS_KEY ? {} : { dev_otp: otp })
  });
});

// ── Verify OTP & Login/Register ───────────────────────────────
router.post("/verify-otp", (req, res) => {
  const { phone, otp, name, role } = req.body;
  if (!phone || !otp) return res.status(400).json({ error: "Phone and OTP required" });

  const stored = store.data.otpStore[phone];
  if (!stored || stored.otp !== otp || Date.now() > stored.expiry) {
    return res.status(401).json({ error: "Invalid or expired OTP" });
  }

  delete store.data.otpStore[phone];

  let user = store.findUser({ phone });
  if (!user) {
    user = store.createUser({
      name: name || "User",
      phone,
      role: role || "customer",
      isVerified: true,
      addresses: []
    });
  } else if (user.isSuspended) {
    return res.status(403).json({ error: "Account suspended. Contact support." });
  }

  const token = generateToken(user);
  res.json({
    success: true,
    token,
    user: { _id: user._id, name: user.name, phone: user.phone, role: user.role, isSuspended: user.isSuspended }
  });
});

// ── Get Profile ───────────────────────────────────────────────
router.get("/profile", (req, res) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: "No token" });
  try {
    const decoded = jwt.verify(auth.split(" ")[1], JWT_SECRET);
    const user = store.findUser({ _id: decoded.id });
    if (!user) return res.status(404).json({ error: "User not found" });
    res.json({ user });
  } catch (e) {
    res.status(401).json({ error: "Invalid token" });
  }
});

// ── Update Profile ────────────────────────────────────────────
router.put("/profile", (req, res) => {
  const auth = req.headers.authorization;
  if (!auth) return res.status(401).json({ error: "No token" });
  try {
    const decoded = jwt.verify(auth.split(" ")[1], JWT_SECRET);
    const idx = store.data.users.findIndex(u => u._id === decoded.id);
    if (idx === -1) return res.status(404).json({ error: "User not found" });
    // Don't allow updating role or suspension status
    const { role, isSuspended, ...safeBody } = req.body;
    store.data.users[idx] = { ...store.data.users[idx], ...safeBody };
    res.json({ user: store.data.users[idx] });
  } catch (e) {
    res.status(401).json({ error: "Invalid token" });
  }
});

// ── Demo Login (no OTP, for testing) ─────────────────────────
router.post("/demo-login", (req, res) => {
  const { phone, role } = req.body;
  let user = store.findUser({ phone });
  if (!user) {
    const names = { admin: "Admin User", merchant: "Restaurant Owner", rider: "Delivery Rider", customer: "Customer" };
    user = store.createUser({
      name: names[role] || "Customer",
      phone,
      role: role || "customer",
      isVerified: true,
      addresses: []
    });
  }
  if (user.isSuspended) return res.status(403).json({ error: "Account suspended." });
  const token = generateToken(user);
  res.json({ success: true, token, user: { _id: user._id, name: user.name, phone: user.phone, role: user.role } });
});

module.exports = router;
