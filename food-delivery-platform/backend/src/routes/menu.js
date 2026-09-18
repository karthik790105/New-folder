const express = require("express");
const router = express.Router();
const store = require("../services/mockStore");

router.get("/restaurant/:restaurantId", (req, res) => {
  const items = store.data.menuItems.filter(m => m.restaurantId === req.params.restaurantId);
  const categories = [...new Set(items.map(i => i.category))];
  res.json({ items, categories });
});

router.post("/", (req, res) => {
  const item = { _id: "menu_" + store.uuidv4().slice(0,8), ...req.body, createdAt: new Date() };
  store.data.menuItems.push(item);
  res.status(201).json({ item });
});

router.put("/:id", (req, res) => {
  const idx = store.data.menuItems.findIndex(m => m._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Not found" });
  store.data.menuItems[idx] = { ...store.data.menuItems[idx], ...req.body };
  req.io.emit("menu_updated", store.data.menuItems[idx]);
  res.json({ item: store.data.menuItems[idx] });
});

router.delete("/:id", (req, res) => {
  const idx = store.data.menuItems.findIndex(m => m._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Not found" });
  store.data.menuItems.splice(idx, 1);
  res.json({ success: true });
});

module.exports = router;
