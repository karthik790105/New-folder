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

// Get nearby restaurants
router.get("/", (req, res) => {
  const { lat, lng, radius = 10, cuisine, search } = req.query;
  let restaurants = store.data.restaurants.filter(r => r.isApproved);
  
  if (lat && lng) {
    restaurants = restaurants.filter(r => haversine(+lat, +lng, r.lat, r.lng) <= +radius);
    restaurants = restaurants.map(r => ({ ...r, distance: haversine(+lat, +lng, r.lat, r.lng).toFixed(1) }));
  }
  
  if (cuisine) restaurants = restaurants.filter(r => r.cuisineTypes.some(c => c.toLowerCase().includes(cuisine.toLowerCase())));
  if (search) restaurants = restaurants.filter(r => r.name.toLowerCase().includes(search.toLowerCase()));
  
  res.json({ restaurants });
});

// Get all (admin)
router.get("/all", (req, res) => {
  res.json({ restaurants: store.data.restaurants });
});

// Get single restaurant
router.get("/:id", (req, res) => {
  const restaurant = store.data.restaurants.find(r => r._id === req.params.id);
  if (!restaurant) return res.status(404).json({ error: "Restaurant not found" });
  res.json({ restaurant });
});

// Create restaurant
router.post("/", (req, res) => {
  const restaurant = { _id: "rest_" + store.uuidv4().slice(0,8), ...req.body, isApproved: false, createdAt: new Date() };
  store.data.restaurants.push(restaurant);
  res.status(201).json({ restaurant });
});

// Update restaurant
router.put("/:id", (req, res) => {
  const idx = store.data.restaurants.findIndex(r => r._id === req.params.id);
  if (idx === -1) return res.status(404).json({ error: "Not found" });
  store.data.restaurants[idx] = { ...store.data.restaurants[idx], ...req.body };
  req.io.emit("restaurant_updated", store.data.restaurants[idx]);
  res.json({ restaurant: store.data.restaurants[idx] });
});

module.exports = router;
