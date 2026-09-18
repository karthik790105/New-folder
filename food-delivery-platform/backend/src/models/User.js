const mongoose = require("mongoose");

const userSchema = new mongoose.Schema({
  name: { type: String, required: true },
  phone: { type: String, required: true, unique: true },
  email: { type: String },
  role: { type: String, enum: ["customer", "merchant", "rider", "admin"], default: "customer" },
  otp: { type: String },
  otpExpiry: { type: Date },
  isVerified: { type: Boolean, default: false },
  isActive: { type: Boolean, default: true },
  profilePic: { type: String },
  addresses: [{
    label: { type: String, enum: ["Home", "Work", "Other"], default: "Home" },
    address: String,
    lat: Number,
    lng: Number,
    isDefault: { type: Boolean, default: false }
  }],
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("User", userSchema);
