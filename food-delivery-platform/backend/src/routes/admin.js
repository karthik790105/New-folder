const express = require("express");
const router = express.Router();
const store = require("../services/mockStore");

// ── Dashboard Stats ───────────────────────────────────────────
router.get("/stats", (req, res) => {
  const orders = store.data.orders;
  const totalRevenue = orders.filter(o => o.status === "DELIVERED")
    .reduce((sum, o) => sum + (o.pricing?.total || 0), 0);
  const todayOrders = orders.filter(o => {
    const d = new Date(o.createdAt);
    const now = new Date();
    return d.toDateString() === now.toDateString();
  });
  res.json({
    stats: {
      totalOrders: orders.length,
      todayOrders: todayOrders.length,
      totalRevenue,
      todayRevenue: todayOrders.filter(o => o.status === "DELIVERED").reduce((s, o) => s + (o.pricing?.total || 0), 0),
      totalRestaurants: store.data.restaurants.length,
      approvedRestaurants: store.data.restaurants.filter(r => r.isApproved).length,
      totalRiders: store.data.riders.length,
      onlineRiders: store.data.riders.filter(r => r.isOnline && !r.isSuspended).length,
      totalCustomers: store.data.users.filter(u => u.role === "customer").length,
      pendingOrders: orders.filter(o => ["PLACED", "ACCEPTED", "PREPARING", "READY", "DISPATCHED", "PICKED_UP"].includes(o.status)).length,
      totalGroceryStores: store.data.groceryStores.length,
      totalMeatStores: store.data.meatStores.length,
    }
  });
});

// ── Orders ────────────────────────────────────────────────────
router.get("/orders", (req, res) => {
  const { status, date } = req.query;
  let orders = [...store.data.orders].reverse();
  if (status) orders = orders.filter(o => o.status === status);
  if (date) {
    const d = new Date(date);
    orders = orders.filter(o => new Date(o.createdAt).toDateString() === d.toDateString());
  }
  res.json({ orders });
});

// ── Restaurants ───────────────────────────────────────────────
router.get("/restaurants", (req, res) => {
  res.json({ restaurants: store.data.restaurants });
});

router.put("/restaurants/:id/approve", (req, res) => {
  const { isApproved } = req.body;
  const idx = store.data.restaurants.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Restaurant not found" });
  store.data.restaurants[idx].isApproved = isApproved;
  req.io.to(`restaurant_${req.params.id}`).emit("account_status", { isApproved });
  res.json({ restaurant: store.data.restaurants[idx] });
});

router.put("/restaurants/:id/suspend", (req, res) => {
  const { isSuspended, reason } = req.body;
  const idx = store.data.restaurants.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Restaurant not found" });
  store.data.restaurants[idx].isSuspended = isSuspended;
  store.data.restaurants[idx].suspendReason = reason || "";
  if (isSuspended) store.data.restaurants[idx].isOpen = false;
  req.io.to(`restaurant_${req.params.id}`).emit("account_suspended", { reason });
  res.json({ restaurant: store.data.restaurants[idx] });
});

// ── Menu items (admin override) ───────────────────────────────
router.put("/menu/:id/toggle", (req, res) => {
  const { isAvailable } = req.body;
  const idx = store.data.menuItems.findIndex(m => m._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Item not found" });
  store.data.menuItems[idx].isAvailable = isAvailable;
  req.io.emit("menu_updated", store.data.menuItems[idx]);
  res.json({ item: store.data.menuItems[idx] });
});

router.put("/menu/:id/price", (req, res) => {
  const { price } = req.body;
  const idx = store.data.menuItems.findIndex(m => m._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Item not found" });
  store.data.menuItems[idx].price = price;
  store.data.menuItems[idx].adminPriceOverride = true;
  req.io.emit("menu_updated", store.data.menuItems[idx]);
  res.json({ item: store.data.menuItems[idx] });
});

router.post("/menu", (req, res) => {
  const item = { _id: "menu_" + store.uuidv4().slice(0, 8), ...req.body, createdAt: new Date(), adminAdded: true };
  store.data.menuItems.push(item);
  req.io.emit("menu_updated", item);
  res.status(201).json({ item });
});

// ── Riders ────────────────────────────────────────────────────
router.get("/riders", (req, res) => {
  res.json({ riders: store.data.riders });
});

router.put("/riders/:id/approve", (req, res) => {
  const { isApproved } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  store.data.riders[idx].isApproved = isApproved;
  req.io.to(`rider_${req.params.id}`).emit("account_status", { isApproved });
  res.json({ rider: store.data.riders[idx] });
});

router.put("/riders/:id/suspend", (req, res) => {
  const { isSuspended, reason } = req.body;
  const idx = store.data.riders.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Rider not found" });
  store.data.riders[idx].isSuspended = isSuspended;
  store.data.riders[idx].suspendReason = reason || "";
  if (isSuspended) store.data.riders[idx].isOnline = false;
  req.io.to(`rider_${req.params.id}`).emit("account_suspended", { reason });
  res.json({ rider: store.data.riders[idx] });
});

// ── Customers ─────────────────────────────────────────────────
router.get("/customers", (req, res) => {
  const customers = store.data.users.filter(u => u.role === "customer");
  res.json({ customers });
});

router.put("/customers/:id/suspend", (req, res) => {
  const { isSuspended, reason } = req.body;
  const idx = store.data.users.findIndex(u => u._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "User not found" });
  store.data.users[idx].isSuspended = isSuspended;
  store.data.users[idx].suspendReason = reason || "";
  req.io.to(`customer_${req.params.id}`).emit("account_suspended", { reason });
  res.json({ user: store.data.users[idx] });
});

// ── Delivery Config ───────────────────────────────────────────
router.get("/delivery-config", (req, res) => {
  res.json({ config: store.data.deliveryConfig });
});

router.put("/delivery-config", (req, res) => {
  const { baseKm, baseCharge, perKmCharge } = req.body;
  if (baseKm !== undefined) store.data.deliveryConfig.baseKm = baseKm;
  if (baseCharge !== undefined) store.data.deliveryConfig.baseCharge = baseCharge;
  if (perKmCharge !== undefined) store.data.deliveryConfig.perKmCharge = perKmCharge;
  req.io.emit("delivery_config_updated", store.data.deliveryConfig);
  res.json({ config: store.data.deliveryConfig });
});

// ── Grocery Stores ────────────────────────────────────────────
router.get("/grocery-stores", (req, res) => {
  res.json({ stores: store.data.groceryStores });
});

router.put("/grocery-stores/:id/suspend", (req, res) => {
  const { isSuspended } = req.body;
  const idx = store.data.groceryStores.findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Store not found" });
  store.data.groceryStores[idx].isSuspended = isSuspended;
  res.json({ store: store.data.groceryStores[idx] });
});

// ── Meat Stores ───────────────────────────────────────────────
router.get("/meat-stores", (req, res) => {
  res.json({ stores: store.data.meatStores });
});

router.put("/meat-stores/:id/suspend", (req, res) => {
  const { isSuspended } = req.body;
  const idx = store.data.meatStores.findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Store not found" });
  store.data.meatStores[idx].isSuspended = isSuspended;
  res.json({ store: store.data.meatStores[idx] });
});

module.exports = router;
