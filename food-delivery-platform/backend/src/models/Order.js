const mongoose = require("mongoose");

const orderSchema = new mongoose.Schema({
  customerId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
  restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: "Restaurant", required: true },
  riderId: { type: mongoose.Schema.Types.ObjectId, ref: "Rider" },
  
  items: [{
    menuItemId: { type: mongoose.Schema.Types.ObjectId, ref: "MenuItem" },
    name: String,
    price: Number,
    quantity: Number,
    variant: String,
    addOns: [{name: String, price: Number}],
    total: Number
  }],
  
  status: {
    type: String,
    enum: ["PLACED", "ACCEPTED", "REJECTED", "PREPARING", "READY", "DISPATCHED", "PICKED_UP", "DELIVERED", "CANCELLED"],
    default: "PLACED"
  },
  
  deliveryAddress: {
    label: String,
    address: String,
    lat: Number,
    lng: Number,
    instructions: String
  },
  
  payment: {
    method: { type: String, enum: ["CARD", "UPI", "COD", "WALLET"], default: "COD" },
    status: { type: String, enum: ["PENDING", "PAID", "REFUNDED"], default: "PENDING" },
    transactionId: String
  },
  
  pricing: {
    subtotal: Number,
    deliveryFee: Number,
    taxes: Number,
    discount: Number,
    total: Number
  },
  
  deliveryOTP: String,
  
  timeline: [{
    status: String,
    timestamp: { type: Date, default: Date.now },
    note: String
  }],
  
  prepTime: { type: Number, default: 25 },
  estimatedDeliveryTime: Number,
  
  commission: Number,
  riderEarnings: Number,
  merchantEarnings: Number,
  
  rating: { type: Number, min: 1, max: 5 },
  review: String,
  
  createdAt: { type: Date, default: Date.now },
  updatedAt: { type: Date, default: Date.now }
});

orderSchema.pre('save', function(next) {
  this.updatedAt = new Date();
  next();
});

module.exports = mongoose.model("Order", orderSchema);
