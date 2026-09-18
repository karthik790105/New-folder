// Socket.IO room manager for Go Fresh platform
// Rooms: customer_<id>, restaurant_<id>, rider_<id>, admin

const initSocket = (io) => {
  io.on("connection", (socket) => {
    console.log(`Socket connected: ${socket.id}`);

    // Join room based on role
    socket.on("join", ({ userId, role, riderId, restaurantId }) => {
      if (role === "customer" && userId) {
        socket.join(`customer_${userId}`);
        console.log(`Customer ${userId} joined room`);
      }
      if (role === "merchant" && restaurantId) {
        socket.join(`restaurant_${restaurantId}`);
        console.log(`Restaurant ${restaurantId} joined room`);
      }
      if (role === "rider" && riderId) {
        socket.join(`rider_${riderId}`);
        socket.join("riders_pool"); // All riders room for new order broadcasts
        console.log(`Rider ${riderId} joined room`);
      }
      if (role === "admin") {
        socket.join("admin");
        console.log(`Admin joined room`);
      }
      socket.emit("joined", { success: true });
    });

    // Join specific order room (for tracking)
    socket.on("track_order", ({ orderId }) => {
      socket.join(`order_${orderId}`);
    });

    // Rider goes online — join riders pool
    socket.on("rider_online", ({ riderId }) => {
      socket.join("riders_pool");
      socket.join(`rider_${riderId}`);
    });

    // Rider goes offline — leave riders pool
    socket.on("rider_offline", ({ riderId }) => {
      socket.leave("riders_pool");
    });

    socket.on("disconnect", () => {
      console.log(`Socket disconnected: ${socket.id}`);
    });
  });
};

module.exports = { initSocket };
