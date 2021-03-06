import 'package:courier_driver_tracker/services/file_handling/route_logging.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'dart:async';
import 'dart:io';
import 'dart:convert';
import 'package:courier_driver_tracker/services/api_handler/uncalculated_route_model.dart';
import 'package:geolocator/geolocator.dart';
import 'package:courier_driver_tracker/services/location/geolocator_service.dart';
import 'package:geolocator/geolocator.dart';
import 'package:courier_driver_tracker/services/location/geolocator_service.dart';

class ApiHandler {
  final storage = new FlutterSecureStorage();

  Map<String, String> requestHeaders = {
    'Accept': 'application/json',
    'Authorization': 'Bearer ' +
        String.fromEnvironment('BEARER_TOKEN',
            defaultValue: DotEnv().env['BEARER_TOKEN'])
  };

  String apiUrl =
      String.fromEnvironment('API_URL', defaultValue: DotEnv().env['API_URL']);

  GeolocatorService geolocatorService = new GeolocatorService();
  Position position;

  ApiHandler();

  Future<String> get localPath async {
    final directory = await getApplicationDocumentsDirectory();
    return directory.path;
  }

  Future<File> getFile(String filename) async {
    final path = await localPath;
    return File('$path/$filename');
  }

  Future<dynamic> callUncalulatedRoute() async {
    var driverID = await storage.read(key: 'id');

    var response =
        await http.get("$apiUrl/api/routes/$driverID", headers: requestHeaders);
    return response.body;
  }

  Future<double> getDriverScore() async {
    var driverID = await storage.read(key: 'id');

    var response = await http.get("$apiUrl/api/driver-score/$driverID",
        headers: requestHeaders);
    Map<String, dynamic> json = jsonDecode(response.body);
    return json['score'].toDouble();
  }

  Future<List<dynamic>> getDriverAbnormalities() async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');

    Map<String, dynamic> data = {
      "id": driverID,
      "token": token,
    };

    var response = await http.post("$apiUrl/api/driver-score/recent",
        headers: requestHeaders, body: data);

    List<dynamic> json = jsonDecode(response.body);
    return json;
  }

  Future<File> initDriverRoute() async {
    var route = await callUncalulatedRoute();
    final file = await getFile("routes-uncalculated.txt");
    return file.writeAsString(route.toString());
  }

  Future<List<Route>> getUncalculatedRoute() async {
    try {
      final file = await getFile("routes-uncalculated.txt");
      String contents = await file.readAsString();
      var routes = json.decode(contents);
      List<Route> routeList = List<Route>();
      for (var route in routes['active_routes']) {
        int k = 0;
        routeList.add(Route.fromJson(route));
        for (var location in route['locations']) {
          routeList[k].addLocation(Location.fromJson(location));
        }
        k++;
        storage.write(key: 'num-routes', value: '$k');
      }
      return routeList;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<dynamic> callCalculateRoute(routeID) async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');
    await storage.write(key: 'RouteID', value: routeID);

    Map<String, dynamic> data = {
      "id": driverID,
      "token": token,
      "route_id": routeID
    };
    var response = await http.post("$apiUrl/api/google-maps/navigation",
        headers: requestHeaders, body: data);

    return response;
  }

  Future<File> initCalculatedRoute(routeID) async {
    var response = await callCalculateRoute(routeID);
    if (response.statusCode == 200) {
      var responseData = response.body;
      final file = await getFile("active-calculated-route.txt");
      return file.writeAsString(responseData.toString());
    } else {
      return null;
    }
  }

  Future<dynamic> getActiveCalculatedRoute() async {
    try {
      final file = await getFile("active-calculated-route.txt");
      String contents = await file.readAsString();
      var route = json.decode(contents);
      return route;
    } catch (e) {
      print(e.toString());
      return null;
    }
  }

  Future<dynamic> updateDriverPassword(password) async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');

    Map<String, dynamic> data = {
      "token": token,
      "password": password.toString()
    };

    var response = await http.put("$apiUrl/api/drivers/$driverID/password",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  Future<dynamic> forgotPassword(email) async {
    Map<String, dynamic> data = {"email": email.toString()};

    var response = await http.put("$apiUrl/api/drivers/forgotpassword",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  // PUT /api/location/:driverid
  Future<dynamic> updateDriverLocation(LatLng position) async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');

    Map<String, dynamic> data = {
      "token": token,
      "latitude": position.latitude.toString(),
      "longitude": position.longitude.toString()
    };

    var response = await http.put("$apiUrl/api/location/$driverID",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  Future<dynamic> updateDriverLocationNoCoords() async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');
    position = await geolocatorService.getPosition();
    String lat = position.latitude.toString();
    String long = position.longitude.toString();

    Map<String, dynamic> data = {
      "token": token,
      "latitude": lat,
      "longitude": long
    };

    var response = await http.put("$apiUrl/api/location/$driverID",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  //TODO double check uct timestamp value in database
  Future<dynamic> completeDelivery(String locationID, Position position) async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');

    Map<String, dynamic> data = {
      "token": token,
      "id": driverID,
      "timestamp": DateTime.now().toString().substring(0, 19)
    };

    var response = await http.put("$apiUrl/api/routes/location/$locationID",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  //TODO double check uct timestamp value in database
  Future<dynamic> completeRoute(String routeID, Position position) async {
    var driverID = await storage.read(key: 'id');
    var token = await storage.read(key: 'token');

    Map<String, dynamic> data = {
      "token": token,
      "id": driverID,
      "timestamp": position.timestamp.toString()
    };

    var response = await http.put("$apiUrl/api/routes/completed/$routeID",
        headers: requestHeaders, body: data);

    return response.statusCode;
  }

  Future<String> getActiveRouteID(int currentRoute) async {
    List<Route> routes = await getUncalculatedRoute();
    if (currentRoute < routes.length - 1) {
      return routes[currentRoute].routeID;
    } else {
      print("Dev: error retrieving route id. Out of bounds.");
      return "";
    }
  }
}
