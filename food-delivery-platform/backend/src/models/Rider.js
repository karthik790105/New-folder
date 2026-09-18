const mongoose = require("mongoose");

const riderSchema = new mongoose.Schema({
  userId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  name: { type: String, required: true },
  phone: { type: String, required: true },
  email: String,
  vehicleType: { type: String, enum: ["bike", "bicycle", "scooter", "car"], default: "bike" },
  vehicleNumber: String,
  vehicleModel: String,
  licenseNumber: String,
  govtId: String,
  isVerified: { type: Boolean, default: false },
  isApproved: { type: Boolean, default: false },
  isOnline: { type: Boolean, default: false },
  isAvailable: { type: Boolean, default: true },
  currentLat: Number,
  currentLng: Number,
  rating: { type: Number, default: 4.5 },
  totalDeliveries: { type: Number, default: 0 },
  totalEarnings: { type: Number, default: 0 },
  todayEarnings: { type: Number, default: 0 },
  bankAccount: String,
  ifscCode: String,
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("Rider", riderSchema);
