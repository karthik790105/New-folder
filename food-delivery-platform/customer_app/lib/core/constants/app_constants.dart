class AppConstants {
  static const String baseUrl = 'http://10.0.2.2:5000/api'; // Android emulator
  // static const String baseUrl = 'http://localhost:5000/api'; // iOS simulator
  // static const String baseUrl = 'http://YOUR_LOCAL_IP:5000/api'; // Physical device

  static const String socketUrl = 'http://10.0.2.2:5000';

  // Endpoints
  static const String sendOtp = '/auth/send-otp';
  static const String verifyOtp = '/auth/verify-otp';
  static const String profile = '/auth/profile';
  static const String restaurants = '/restaurants';
  static const String groceryStores = '/stores/grocery';
  static const String meatStores = '/stores/meat';
  static const String menu = '/menu/restaurant';
  static const String orders = '/orders';
  static const String deliveryConfig = '/admin/delivery-config';
}
