const express = require("express");
const router = express.Router();
const store = require("../services/mockStore");

// Get all riders (admin)
router.get("/", (req, res) => {
  res.json({ riders: store.data.riders });
});

// Get single rider
router.get("/:id", (req, res) => {
  const rider = store.data.riders.find(r => r._id === req.params.id);
  if (!rider) return res.status(404).json({ error: "Rider not found" });
  res.json({ rider });
});

// Register / upsert rider profile
router.post("/", (req, res) => {
  const { userId, name, phone, vehicleType, vehicleNumber } = req.body;
  const existing = store.data.riders.find(r => r.userId === userId);
  if (existing) return res.json({ rider: existing });
  const rider = {
    _id: "rider_" + store.uuidv4().slice(0, 8),
    userId, name, phone,
    vehicleType: vehicleType || "bike",
    vehicleNumber: vehicleNumber || "",
    isVerified: false,
    isApproved: false,
    isSuspended: false,
    isOnline: false,
    isAvailable: false,
    currentLat: null,
    currentLng: null,
    rating: 0,
    totalDeliveries: 0,
    totalEarnings: 0,
    todayEarnings: 0,
    createdAt: new Date()
  };
  store.data.riders.push(rider);
  res.status(201).json({ rider });
});

// Toggle online/offline status
router.put("/:id/status", (req, res) => {
  const { isOnline, isAvailable } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  if (store.data.riders[idx].isSuspended) return res.status(403).json({ error: "Rider is suspended" });
  if (isOnline !== undefined) store.data.riders[idx].isOnline = isOnline;
  if (isAvailable !== undefined) store.data.riders[idx].isAvailable = isAvailable;
  req.io.emit("rider_status_changed", store.data.riders[idx]);
  res.json({ rider: store.data.riders[idx] });
});

// Update live GPS location
router.put("/:id/location", (req, res) => {
  const { lat, lng } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  store.data.riders[idx].currentLat = lat;
  store.data.riders[idx].currentLng = lng;
  // Broadcast location to relevant customers
  req.io.emit("rider_location_update", { riderId: req.params.id, lat, lng });
  res.json({ success: true });
});

// Get rider earnings
router.get("/:id/earnings", (req, res) => {
  const rider = store.data.riders.find(r => r._id === req.params.id);
  if (!rider) return res.status(404).json({ error: "Rider not found" });
  const riderOrders = store.data.orders.filter(o => o.riderId === req.params.id && o.status === "DELIVERED");
  res.json({
    todayEarnings: rider.todayEarnings,
    totalEarnings: rider.totalEarnings,
    totalDeliveries: rider.totalDeliveries,
    recentOrders: riderOrders.slice(-10).reverse()
  });
});

// Admin: approve / suspend rider
router.put("/:id/approve", (req, res) => {
  const { isApproved } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  store.data.riders[idx].isApproved = isApproved;
  res.json({ rider: store.data.riders[idx] });
});

router.put("/:id/suspend", (req, res) => {
  const { isSuspended, reason } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  store.data.riders[idx].isSuspended = isSuspended;
  store.data.riders[idx].suspendReason = reason || "";
  if (isSuspended) store.data.riders[idx].isOnline = false;
  req.io.to(`rider_${req.params.id}`).emit("account_suspended", { reason });
  res.json({ rider: store.data.riders[idx] });
});

module.exports = router;
