const express = require("express");
const router = express.Router();
const store = require("../services/mockStore");

// ── Grocery Stores ────────────────────────────────────────────
router.get("/grocery", (req, res) => {
  const { lat, lng, search } = req.query;
  let stores = store.data.groceryStores.filter(s => s.isApproved && !s.isSuspended);
  if (search) stores = stores.filter(s => s.name.toLowerCase().includes(search.toLowerCase()));
  res.json({ stores });
});

router.get("/grocery/:id", (req, res) => {
  const s = store.data.groceryStores.find(s => s._id === req.params.id);
  if (!s) return res.status(404).json({ error: "Store not found" });
  res.json({ store: s });
});

router.post("/grocery", (req, res) => {
  const s = { _id: "groc_" + store.uuidv4().slice(0, 8), ...req.body, isApproved: false, isSuspended: false, createdAt: new Date() };
  store.data.groceryStores.push(s);
  res.status(201).json({ store: s });
});

router.put("/grocery/:id", (req, res) => {
  const idx = store.data.groceryStores.findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Not found" });
  store.data.groceryStores[idx] = { ...store.data.groceryStores[idx], ...req.body };
  res.json({ store: store.data.groceryStores[idx] });
});

// ── Meat Stores ───────────────────────────────────────────────
router.get("/meat", (req, res) => {
  const { search } = req.query;
  let stores = store.data.meatStores.filter(s => s.isApproved && !s.isSuspended);
  if (search) stores = stores.filter(s => s.name.toLowerCase().includes(search.toLowerCase()));
  res.json({ stores });
});

router.get("/meat/:id", (req, res) => {
  const s = store.data.meatStores.find(s => s._id === req.params.id);
  if (!s) return res.status(404).json({ error: "Store not found" });
  res.json({ store: s });
});

router.post("/meat", (req, res) => {
  const s = { _id: "meat_" + store.uuidv4().slice(0, 8), ...req.body, isApproved: false, isSuspended: false, createdAt: new Date() };
  store.data.meatStores.push(s);
  res.status(201).json({ store: s });
});

router.put("/meat/:id", (req, res) => {
  const idx = store.data.meatStores.findIndex(s => s._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Not found" });
  store.data.meatStores[idx] = { ...store.data.meatStores[idx], ...req.body };
  res.json({ store: store.data.meatStores[idx] });
});

module.exports = router;
