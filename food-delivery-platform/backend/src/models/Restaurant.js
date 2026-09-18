const mongoose = require("mongoose");

const restaurantSchema = new mongoose.Schema({
  ownerId: { type: mongoose.Schema.Types.ObjectId, ref: "User" },
  name: { type: String, required: true },
  description: String,
  cuisineTypes: [String],
  address: String,
  lat: { type: Number, required: true },
  lng: { type: Number, required: true },
  phone: String,
  email: String,
  logo: String,
  coverImage: String,
  rating: { type: Number, default: 4.2, min: 0, max: 5 },
  reviewCount: { type: Number, default: 0 },
  isOpen: { type: Boolean, default: true },
  isApproved: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true },
  avgDeliveryTime: { type: Number, default: 30 },
  minOrder: { type: Number, default: 100 },
  deliveryFee: { type: Number, default: 40 },
  fssaiLicense: String,
  gstNumber: String,
  bankAccount: String,
  ifscCode: String,
  operatingHours: {
    open: { type: String, default: "08:00" },
    close: { type: String, default: "23:00" },
    days: [String]
  },
  commissionRate: { type: Number, default: 20 },
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("Restaurant", restaurantSchema);
