// In-memory mock data store - works without MongoDB
const { v4: uuidv4 } = require("uuid");

const mockData = {
  users: [
    { _id: "usr_1", name: "Priya Sharma", phone: "9876543210", role: "customer", isVerified: true, isSuspended: false, addresses: [{ label: "Home", address: "12 MG Road, Bangalore", lat: 12.9716, lng: 77.5946, isDefault: true }] },
    { _id: "usr_2", name: "Rajesh Kumar", phone: "9123456780", role: "merchant", isVerified: true, isSuspended: false },
    { _id: "usr_3", name: "Arjun Singh", phone: "9988776655", role: "rider", isVerified: true, isSuspended: false },
    { _id: "usr_4", name: "Admin User", phone: "9000000000", role: "admin", isVerified: true, isSuspended: false }
  ],
  restaurants: [
    { _id: "rest_1", ownerId: "usr_2", name: "Spice Garden", description: "Authentic South Indian cuisine", cuisineTypes: ["South Indian", "Biryani"], address: "45 Koramangala, Bangalore", lat: 12.9352, lng: 77.6245, rating: 4.5, reviewCount: 234, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 30, minOrder: 150, deliveryFee: 30, logo: null, commissionRate: 20 },
    { _id: "rest_2", ownerId: "usr_2", name: "Pizza Paradise", description: "Wood-fired pizzas & pastas", cuisineTypes: ["Italian", "Pizza"], address: "78 Indiranagar, Bangalore", lat: 12.9784, lng: 77.6408, rating: 4.2, reviewCount: 178, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 25, minOrder: 200, deliveryFee: 50, logo: null, commissionRate: 20 },
    { _id: "rest_3", ownerId: "usr_2", name: "Burger Barn", description: "Gourmet burgers & fries", cuisineTypes: ["American", "Burgers"], address: "23 HSR Layout, Bangalore", lat: 12.9116, lng: 77.6389, rating: 4.0, reviewCount: 92, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 20, minOrder: 100, deliveryFee: 25, logo: null, commissionRate: 20 },
    { _id: "rest_4", ownerId: "usr_2", name: "Green Bowl", description: "Healthy salads & smoothies", cuisineTypes: ["Healthy", "Salads"], address: "56 Whitefield, Bangalore", lat: 12.9698, lng: 77.7499, rating: 4.7, reviewCount: 145, isOpen: false, isApproved: false, isSuspended: false, avgDeliveryTime: 35, minOrder: 200, deliveryFee: 40, logo: null, commissionRate: 20 }
  ],
  groceryStores: [
    { _id: "groc_1", ownerId: "usr_2", name: "Daily Fresh Mart", description: "Fresh vegetables, fruits & daily essentials", address: "12 Koramangala, Bangalore", lat: 12.9360, lng: 77.6250, rating: 4.3, reviewCount: 120, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 40, minOrder: 100, deliveryFee: 20, logo: null, commissionRate: 15 },
    { _id: "groc_2", ownerId: "usr_2", name: "SuperStore", description: "All grocery needs under one roof", address: "34 Indiranagar, Bangalore", lat: 12.9790, lng: 77.6410, rating: 4.1, reviewCount: 85, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 45, minOrder: 150, deliveryFee: 25, logo: null, commissionRate: 15 }
  ],
  meatStores: [
    { _id: "meat_1", ownerId: "usr_2", name: "Fresh Cuts", description: "Fresh chicken, mutton & seafood", address: "67 Jayanagar, Bangalore", lat: 12.9250, lng: 77.5830, rating: 4.6, reviewCount: 210, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 50, minOrder: 200, deliveryFee: 30, logo: null, commissionRate: 18 },
    { _id: "meat_2", ownerId: "usr_2", name: "Protein Hub", description: "Premium quality meats & seafood", address: "89 BTM Layout, Bangalore", lat: 12.9170, lng: 77.6101, rating: 4.4, reviewCount: 156, isOpen: true, isApproved: true, isSuspended: false, avgDeliveryTime: 55, minOrder: 250, deliveryFee: 35, logo: null, commissionRate: 18 }
  ],
  menuItems: [
    { _id: "menu_1", restaurantId: "rest_1", storeType: "restaurant", name: "Masala Dosa", description: "Crispy dosa with spiced potato filling", category: "Breakfast", price: 120, isVeg: true, isAvailable: true, rating: 4.8, prepTime: 15, addOns: [{name: "Extra Chutney", price: 10}, {name: "Sambar", price: 15}] },
    { _id: "menu_2", restaurantId: "rest_1", storeType: "restaurant", name: "Chicken Biryani", description: "Aromatic basmati rice with tender chicken", category: "Main Course", price: 280, isVeg: false, isAvailable: true, rating: 4.6, prepTime: 30, addOns: [{name: "Raita", price: 30}, {name: "Salan", price: 25}] },
    { _id: "menu_3", restaurantId: "rest_1", storeType: "restaurant", name: "Filter Coffee", description: "Traditional South Indian filter coffee", category: "Beverages", price: 60, isVeg: true, isAvailable: true, rating: 4.9, prepTime: 5 },
    { _id: "menu_4", restaurantId: "rest_1", storeType: "restaurant", name: "Idli Vada Combo", description: "3 idlis + 2 vadas with chutneys", category: "Breakfast", price: 90, isVeg: true, isAvailable: false, rating: 4.5, prepTime: 20 },
    { _id: "menu_5", restaurantId: "rest_2", storeType: "restaurant", name: "Margherita Pizza", description: "Classic tomato, mozzarella & basil", category: "Pizza", price: 350, isVeg: true, isAvailable: true, rating: 4.3, prepTime: 25, variants: [{name: "Small 8\"", price: 250}, {name: "Medium 10\"", price: 350}, {name: "Large 12\"", price: 450}] },
    { _id: "menu_6", restaurantId: "rest_2", storeType: "restaurant", name: "Pepperoni Pizza", description: "Spicy pepperoni with cheese", category: "Pizza", price: 420, isVeg: false, isAvailable: true, rating: 4.5, prepTime: 25 },
    { _id: "menu_7", restaurantId: "rest_2", storeType: "restaurant", name: "Penne Arrabbiata", description: "Spicy tomato sauce pasta", category: "Pasta", price: 280, isVeg: true, isAvailable: true, rating: 4.1, prepTime: 20 },
    { _id: "menu_8", restaurantId: "rest_3", storeType: "restaurant", name: "Classic Burger", description: "Beef patty with lettuce, tomato & cheese", category: "Burgers", price: 220, isVeg: false, isAvailable: true, rating: 4.2, prepTime: 15, addOns: [{name: "Extra Patty", price: 80}, {name: "Cheese", price: 30}] },
    { _id: "menu_9", restaurantId: "rest_3", storeType: "restaurant", name: "Crispy Fries", description: "Golden crispy french fries", category: "Sides", price: 100, isVeg: true, isAvailable: true, rating: 4.0, prepTime: 10 },
    // Grocery items
    { _id: "menu_10", restaurantId: "groc_1", storeType: "grocery", name: "Fresh Tomatoes", description: "Farm fresh tomatoes - 1 kg", category: "Vegetables", price: 40, isVeg: true, isAvailable: true, unit: "kg" },
    { _id: "menu_11", restaurantId: "groc_1", storeType: "grocery", name: "Basmati Rice", description: "Premium basmati rice - 1 kg", category: "Grains", price: 120, isVeg: true, isAvailable: true, unit: "kg" },
    { _id: "menu_12", restaurantId: "groc_1", storeType: "grocery", name: "Full Cream Milk", description: "Fresh full cream milk - 500ml", category: "Dairy", price: 30, isVeg: true, isAvailable: true, unit: "500ml" },
    // Meat items
    { _id: "menu_13", restaurantId: "meat_1", storeType: "meat", name: "Chicken Breast", description: "Fresh boneless chicken breast - 500g", category: "Chicken", price: 180, isVeg: false, isAvailable: true, unit: "500g" },
    { _id: "menu_14", restaurantId: "meat_1", storeType: "meat", name: "Mutton Curry Cut", description: "Fresh mutton curry cut - 500g", category: "Mutton", price: 350, isVeg: false, isAvailable: true, unit: "500g" },
    { _id: "menu_15", restaurantId: "meat_1", storeType: "meat", name: "Prawns", description: "Fresh medium prawns - 500g", category: "Seafood", price: 280, isVeg: false, isAvailable: true, unit: "500g" },
  ],
  riders: [
    { _id: "rider_1", userId: "usr_3", name: "Arjun Singh", phone: "9988776655", vehicleType: "bike", vehicleNumber: "KA01AB1234", isVerified: true, isApproved: true, isSuspended: false, isOnline: true, isAvailable: true, currentLat: 12.9500, currentLng: 77.6100, rating: 4.8, totalDeliveries: 342, totalEarnings: 68400, todayEarnings: 850 }
  ],
  orders: [],
  otpStore: {},
  // Delivery pricing config: ₹10 for first 1km, ₹5 per km after
  deliveryConfig: {
    baseKm: 1,
    baseCharge: 10,
    perKmCharge: 5
  }
};

const generateOTP = () => Math.floor(100000 + Math.random() * 900000).toString();

// Calculate delivery fee based on config
const calculateDeliveryFee = (distanceKm) => {
  const config = mockData.deliveryConfig;
  if (distanceKm <= config.baseKm) return config.baseCharge;
  return config.baseCharge + Math.ceil(distanceKm - config.baseKm) * config.perKmCharge;
};

module.exports = {
  data: mockData,
  generateOTP,
  calculateDeliveryFee,
  uuidv4,
  findUser: (query) => {
    if (query._id) return mockData.users.find(u => u._id === query._id);
    if (query.phone) return mockData.users.find(u => u.phone === query.phone);
    return null;
  },
  createUser: (userData) => {
    const user = { _id: uuidv4(), ...userData, isSuspended: false, createdAt: new Date() };
    mockData.users.push(user);
    return user;
  },
  findOrders: (query) => {
    let orders = mockData.orders;
    if (query.customerId) orders = orders.filter(o => o.customerId === query.customerId);
    if (query.restaurantId) orders = orders.filter(o => o.restaurantId === query.restaurantId);
    if (query.riderId) orders = orders.filter(o => o.riderId === query.riderId);
    if (query.status) orders = orders.filter(o => o.status === query.status);
    return orders;
  },
  createOrder: (orderData) => {
    const deliveryOTP = generateOTP().slice(0, 4);
    const order = {
      _id: "ord_" + uuidv4().slice(0, 8),
      ...orderData,
      status: "PLACED",
      deliveryOTP,
      timeline: [{ status: "PLACED", timestamp: new Date(), note: "Order placed by customer" }],
      createdAt: new Date()
    };
    mockData.orders.push(order);
    return order;
  },
  updateOrder: (orderId, updates) => {
    const idx = mockData.orders.findIndex(o => o._id === orderId);
    if (idx === -1) return null;
    mockData.orders[idx] = { ...mockData.orders[idx], ...updates, updatedAt: new Date() };
    return mockData.orders[idx];
  }
};
