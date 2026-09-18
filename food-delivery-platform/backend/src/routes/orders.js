const express = require("express");
const router = express.Router();
const store = require("../services/mockStore");

// Haversine distance in km
function haversine(lat1, lng1, lat2, lng2) {
  const R = 6371;
  const dLat = (lat2 - lat1) * Math.PI / 180;
  const dLng = (lng2 - lng1) * Math.PI / 180;
  const a = Math.sin(dLat/2)**2 + Math.cos(lat1*Math.PI/180) * Math.cos(lat2*Math.PI/180) * Math.sin(dLng/2)**2;
  return R * 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1-a));
}

// Place order
router.post("/", (req, res) => {
  const { customerId, restaurantId, storeType, items, deliveryAddress, payment, pricing } = req.body;
  if (!customerId || !restaurantId || !items) return res.status(400).json({ error: "Missing required fields" });

  // Check customer not suspended
  const customer = store.findUser({ _id: customerId });
  if (customer?.isSuspended) return res.status(403).json({ error: "Account suspended" });

  // Calculate delivery fee dynamically
  let calculatedDeliveryFee = pricing?.deliveryFee || 10;
  if (deliveryAddress?.lat && deliveryAddress?.lng) {
    let storeLat, storeLng;
    const restaurant = store.data.restaurants.find(r => r._id === restaurantId);
    const grocery = store.data.groceryStores.find(s => s._id === restaurantId);
    const meat = store.data.meatStores.find(s => s._id === restaurantId);
    const source = restaurant || grocery || meat;
    if (source) {
      const dist = haversine(source.lat, source.lng, deliveryAddress.lat, deliveryAddress.lng);
      calculatedDeliveryFee = store.calculateDeliveryFee(dist);
    }
  }

  const finalPricing = { ...pricing, deliveryFee: calculatedDeliveryFee };
  const order = store.createOrder({ customerId, restaurantId, storeType: storeType || "restaurant", items, deliveryAddress, payment, pricing: finalPricing });

  // Get customer info for notifications
  const customerInfo = customer ? { name: customer.name, phone: customer.phone } : {};
  const orderWithCustomer = { ...order, customerInfo };

  // Notify restaurant
  req.io.to(`restaurant_${restaurantId}`).emit("new_order", orderWithCustomer);
  // Notify ALL online riders
  req.io.to("riders_pool").emit("new_order", orderWithCustomer);
  // Notify admin
  req.io.to("admin").emit("new_order", orderWithCustomer);
  // Notify customer
  req.io.to(`customer_${customerId}`).emit("order_update", order);

  console.log(`\n🛒 New Order: ${order._id} | Customer: ${customerInfo.name} | OTP: ${order.deliveryOTP}\n`);

  res.status(201).json({ order });
});

// Get orders
router.get("/", (req, res) => {
  const { customerId, restaurantId, riderId, status } = req.query;
  const orders = store.findOrders({ customerId, restaurantId, riderId, status });
  res.json({ orders });
});

// Get single order
router.get("/:id", (req, res) => {
  const order = store.data.orders.find(o => o._id === req.params.id);
  if (!order) return res.status(404).json({ error: "Order not found" });
  // Attach customer info
  const customer = store.findUser({ _id: order.customerId });
  const orderWithCustomer = { ...order, customerInfo: customer ? { name: customer.name, phone: customer.phone } : {} };
  res.json({ order: orderWithCustomer });
});

// Update order status
router.put("/:id/status", (req, res) => {
  const { status, note, riderId } = req.body;
  const order = store.data.orders.find(o => o._id === req.params.id);
  if (!order) return res.status(404).json({ error: "Order not found" });

  const validTransitions = {
    PLACED: ["ACCEPTED", "REJECTED", "CANCELLED"],
    ACCEPTED: ["PREPARING", "CANCELLED"],
    PREPARING: ["READY"],
    READY: ["DISPATCHED"],
    DISPATCHED: ["PICKED_UP"],
    PICKED_UP: ["DELIVERED"],
  };

  if (validTransitions[order.status] && !validTransitions[order.status].includes(status)) {
    return res.status(400).json({ error: `Cannot transition from ${order.status} to ${status}` });
  }

  const updates = {
    status,
    timeline: [...order.timeline, { status, timestamp: new Date(), note: note || "" }]
  };
  if (riderId) updates.riderId = riderId;

  const updated = store.updateOrder(req.params.id, updates);
  const customer = store.findUser({ _id: order.customerId });
  const updatedWithCustomer = { ...updated, customerInfo: customer ? { name: customer.name, phone: customer.phone } : {} };

  // Broadcast to all relevant parties
  req.io.to(`order_${req.params.id}`).emit("order_status_changed", updatedWithCustomer);
  req.io.to(`customer_${order.customerId}`).emit("order_update", updatedWithCustomer);
  req.io.to(`restaurant_${order.restaurantId}`).emit("order_update", updatedWithCustomer);
  if (updated.riderId) req.io.to(`rider_${updated.riderId}`).emit("order_update", updatedWithCustomer);
  req.io.to("admin").emit("admin_order_update", updatedWithCustomer);

  res.json({ order: updatedWithCustomer });
});

// Verify delivery OTP (rider enters OTP from customer)
router.post("/:id/verify-otp", (req, res) => {
  const { otp } = req.body;
  const order = store.data.orders.find(o => o._id === req.params.id);
  if (!order) return res.status(404).json({ error: "Order not found" });
  if (order.deliveryOTP !== otp) return res.status(400).json({ error: "Invalid OTP" });
  if (order.status !== "PICKED_UP") return res.status(400).json({ error: "Order not in PICKED_UP state" });

  const commission = (order.pricing?.itemsTotal || 0) * 0.20;
  const riderEarnings = (order.pricing?.deliveryFee || 10) + 20;
  const merchantEarnings = (order.pricing?.itemsTotal || 0) - commission;

  const updates = {
    status: "DELIVERED",
    timeline: [...order.timeline, { status: "DELIVERED", timestamp: new Date(), note: "OTP verified, order delivered" }],
    commission,
    riderEarnings,
    merchantEarnings
  };

  const updated = store.updateOrder(req.params.id, updates);
  const customer = store.findUser({ _id: order.customerId });
  const updatedWithCustomer = { ...updated, customerInfo: customer ? { name: customer.name, phone: customer.phone } : {} };

  req.io.to(`order_${req.params.id}`).emit("order_status_changed", updatedWithCustomer);
  req.io.to(`customer_${order.customerId}`).emit("order_update", updatedWithCustomer);
  req.io.to(`restaurant_${order.restaurantId}`).emit("order_update", updatedWithCustomer);
  if (updated.riderId) req.io.to(`rider_${updated.riderId}`).emit("order_update", updatedWithCustomer);
  req.io.to("admin").emit("admin_order_update", updatedWithCustomer);

  // Update rider earnings
  const riderIdx = store.data.riders.findIndex(r => r._id === updated.riderId);
  if (riderIdx !== -1) {
    store.data.riders[riderIdx].todayEarnings += riderEarnings;
    store.data.riders[riderIdx].totalEarnings += riderEarnings;
    store.data.riders[riderIdx].totalDeliveries += 1;
    store.data.riders[riderIdx].isAvailable = true;
  }

  res.json({ order: updatedWithCustomer, message: "Order delivered successfully" });
});

module.exports = router;
