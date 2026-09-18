const mongoose = require("mongoose");

const menuItemSchema = new mongoose.Schema({
  restaurantId: { type: mongoose.Schema.Types.ObjectId, ref: "Restaurant", required: true },
  name: { type: String, required: true },
  description: String,
  category: { type: String, required: true },
  price: { type: Number, required: true },
  image: String,
  isVeg: { type: Boolean, default: true },
  isAvailable: { type: Boolean, default: true },
  rating: { type: Number, default: 4.0 },
  prepTime: { type: Number, default: 15 },
  variants: [{
    name: String,
    price: Number
  }],
  addOns: [{
    name: String,
    price: Number
  }],
  tags: [String],
  calories: Number,
  createdAt: { type: Date, default: Date.now }
});

module.exports = mongoose.model("MenuItem", menuItemSchema);
