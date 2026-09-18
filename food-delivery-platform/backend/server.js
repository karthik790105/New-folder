require('dotenv').config();
const express = require('express');
const http = require('http');
const { Server } = require('socket.io');
const cors = require('cors');
const mongoose = require('mongoose');
const path = require('path');

const authRoutes = require('./src/routes/auth');
const restaurantRoutes = require('./src/routes/restaurants');
const orderRoutes = require('./src/routes/orders');
const riderRoutes = require('./src/routes/riders');
const adminRoutes = require('./src/routes/admin');
const menuRoutes = require('./src/routes/menu');
const storeRoutes = require('./src/routes/stores');
const { initSocket } = require('./src/socket/socketManager');

const app = express();
const server = http.createServer(app);
const io = new Server(server, {
  cors: { origin: '*', methods: ['GET', 'POST', 'PUT', 'DELETE'] }
});

app.use(cors({ origin: '*' }));
app.use(express.json());

// Serve Go Fresh brand assets statically
app.use('/assets', express.static(path.join(__dirname, '../assets')));

// Attach io to req for use in routes
app.use((req, res, next) => { req.io = io; next(); });

// Routes
app.use('/api/auth', authRoutes);
app.use('/api/restaurants', restaurantRoutes);
app.use('/api/orders', orderRoutes);
app.use('/api/riders', riderRoutes);
app.use('/api/admin', adminRoutes);
app.use('/api/menu', menuRoutes);
app.use('/api/stores', storeRoutes);

// Health check
app.get('/api/health', (req, res) => res.json({ status: 'ok', brand: 'Go Fresh', time: new Date() }));

// Socket
initSocket(io);

const MONGO_URI = process.env.MONGO_URI || 'mongodb://localhost:27017/gofresh';
const PORT = process.env.PORT || 5000;

mongoose.connect(MONGO_URI)
  .then(() => {
    console.log('MongoDB connected');
    server.listen(PORT, () => console.log(`🚀 Go Fresh Backend running on port ${PORT}`));
  })
  .catch(err => {
    console.error('MongoDB not available, running with in-memory mock data:', err.message);
    server.listen(PORT, () => console.log(`🚀 Go Fresh Backend running on port ${PORT} (mock mode)`));
  });

module.exports = { app, io };
