import 'package:courier_driver_tracker/screens/delivery_screen.dart';
import 'package:courier_driver_tracker/screens/sudden_stop.dart';
import 'package:flutter/material.dart';
import 'screens/login.dart';
import 'screens/home.dart';
import 'screens/splash_screen.dart';
import 'screens/profile.dart';
import 'screens/settings.dart';
import 'screens/long_stop.dart';
import 'screens/sudden_stop.dart';
import 'screens/off_route.dart';
import 'screens/company_car.dart';
import 'screens/speed_exceeded.dart';

class Router {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => SplashScreen(),
        );
        break;
      case '/login':
        return MaterialPageRoute(
          builder: (_) => LoginPage(),
        );
        break;

      case '/home':
        String token = settings.arguments;
        if (token.isNotEmpty) {
          return MaterialPageRoute(
            builder: (_) => HomePage(),
          );
        } else {
          return MaterialPageRoute(
            builder: (_) => LoginPage(),
          );
        }
        break;

      case '/home2':
        return MaterialPageRoute(
          builder: (_) => HomePage(),
        );
        break;

      case '/profile':
        return MaterialPageRoute(
          builder: (_) => ProfileScreen(),
        );
        break;

      case '/settings':
        return MaterialPageRoute(
          builder: (_) => SettingsScreen(),
        );
      case '/reportLong':
       return MaterialPageRoute(builder: (_) => UserFeedbackLong(),);
       break;

      case '/reportSudden':
        return MaterialPageRoute(builder: (_) => UserFeedbackSudden(),);
        break;

      case '/reportOff':
        return MaterialPageRoute(builder: (_) => UserFeedbackOffRoute(),);
        break;

      case '/reportSpeed':
        return MaterialPageRoute(builder: (_) => UserFeedbackSpeed(),);
        break;

      case '/reportCompany':
        return MaterialPageRoute(builder: (_) => UserFeedbackLongCompany(),);
        break;

      case '/delivery':
        return MaterialPageRoute(
          builder: (_) => DeliveryScreen(),
        );

      default: //If page is not found, redirect to loginpage
        return MaterialPageRoute(
          builder: (_) => LoginPage(),
        );
        break;
    }
  }
}
