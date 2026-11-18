import 'package:flutter/material.dart';

IconData mapCategoryIcon(String iconName) {
  return switch (iconName) {
    'restaurant' => Icons.restaurant_outlined,
    'directions_car' => Icons.directions_car_outlined,
    'shopping_cart' => Icons.shopping_cart_outlined,
    'home' => Icons.home_outlined,
    'local_cafe' => Icons.local_cafe_outlined,
    'movie' => Icons.movie_outlined,
    'payments' => Icons.payments_outlined,
    'work' => Icons.work_outline,
    'sync_alt' => Icons.sync_alt_outlined,
    'swap_horiz' => Icons.swap_horiz_outlined,
    _ => Icons.category_outlined,
  };
}
