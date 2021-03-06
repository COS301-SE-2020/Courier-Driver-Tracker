import 'dart:convert';
import 'dart:math';
import 'package:courier_driver_tracker/services/abnormality/abnormality_service.dart';
import 'package:courier_driver_tracker/services/api_handler/api.dart';
import 'package:courier_driver_tracker/services/api_handler/uncalculated_route_model.dart'
    as routeModel;
import 'package:courier_driver_tracker/services/file_handling/route_logging.dart';
import 'package:courier_driver_tracker/services/navigation/delivery_route.dart';
import 'package:courier_driver_tracker/services/notification/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigationService {
  /*
   * Author: Gian Geyser
   * Description: Navigation class.
   */

  static final NavigationService _navigationService = NavigationService._construct();

  DeliveryRoute _deliveryRoutes;
  bool _routesInitialised = false;
  int _currentRoute;
  int _currentLeg; // delivery
  int _currentStep; // directions
  int _lengthRemainingAfterNextDelivery; // number of points on route remaining at next delivery.
  int _lengthRemainingAfterNextStep;
  String jsonFile;
  LocalNotifications _notificationManager = LocalNotifications();
  AbnormalityService _abnormalityService = AbnormalityService();
  Position _position;

  // Map polylines and markers
  Map<String, Polyline> polylines = {};
  Polyline currentPolyline;
  LatLng previousPoint;
  Set<Marker> markers = {};
  Set<Circle> circles = {};
  LatLng northEast;
  LatLng southWest;
  bool atDelivery = false;
  bool nearDelivery = false;

  // info variables
  FlutterSecureStorage _storage = FlutterSecureStorage();
  String directions;
  String deliveryTimeRemaining;
  int distance;
  String distanceString;
  String eta;
  String delivery;
  String deliveryAddress;
  String directionIconPath;

  // observers
  List<dynamic> subscribers = [];

  // Notifications
  Map<String, String> _abnormalityHeaders = {
    "offroute": "Going Off Route!",
    "sudden_stop": "Sudden Stop!",
    "stopping_too_long": "You Stopped Moving!",
    "speeding": "You Are Speeding!",
    "driving_too_slow": "You Are Driving Slow!"
  };
  Map<String, String> _abnormalityMessages = {
    "offroute": "You are going off the prescribed route.",
    "sudden_stop": "You stopped very quickly. Are you OK?",
    "stopping_too_long": "You have stopped for too long.",
    "speeding": "You are driving above the speed limit.",
    "driving_too_slow": "You are driving slow for a while now."
  };

  NavigationService._construct() {
    if(_currentRoute == null && _currentLeg == null && _currentStep == null){
      _currentRoute = -1;
      _currentLeg = 0;
      _currentStep = 0;
    }
  }

  factory NavigationService(){
    return _navigationService;
  }


  //__________________________________________________________________________________________________
  //                            Initialisation
  //__________________________________________________________________________________________________

  initialiseNotifications(BuildContext context) {
    _notificationManager.initializing(context);
  }

  /*
   * Parameters: none
   * Returns: none
   * Description: Turns json from saved file into DeliveryRoute object.
   *
   */
  initialiseRoutes() async {
    String initialised = await _storage.read(key: 'route_initialised');
    if (initialised != "true") {
      _routesInitialised = false;
      return;
    }

    RouteLogging logger = RouteLogging();
    String jsonString = await logger.readFileContents("deliveries");
    if (jsonString == null || jsonString.length == 0) {
      print("Dev: Error initialising routes from json file. [Navigation Service:initialiseRoutes]");
      _routesInitialised = false;
      return;
    }
    Map<String, dynamic> json = jsonDecode(jsonString);
    _deliveryRoutes = DeliveryRoute.fromJson(json);
    _routesInitialised = true;
  }

  initialisePolyPointsAndMarkers(int route) async {
    if (route == -1 || route == null) {
      return;
    }
    if (_deliveryRoutes == null) {
      await initialiseRoutes();
      if (_deliveryRoutes == null) {
        return;
      }
    }

    for (int leg = 0; leg < _deliveryRoutes.routes[route].legs.length; leg++) {
      int delivery = leg + 1;
      Marker marker = Marker(
        markerId: MarkerId('$route-$leg'),
        position: LatLng(
          _deliveryRoutes.routes[route].legs[leg].endLocation.latitude,
          _deliveryRoutes.routes[route].legs[leg].endLocation.longitude,
        ),
        infoWindow: InfoWindow(
          title: 'Delivery $delivery',
          snippet: _deliveryRoutes.routes[route].legs[leg].endAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,

      );
      markers.add(marker);

      List<LatLng> polylineCoordinates = [];
      String polyId = "$route";

      // get polyline points from DeliveryRoute in navigator service
      List<PointLatLng> result = decodeEncodedPolyline(
          _deliveryRoutes.routes[route].overviewPolyline.points);

      // Adding the coordinates to the list
      if (result.isNotEmpty) {
        result.forEach((PointLatLng point) {
          polylineCoordinates.add(LatLng(point.latitude, point.longitude));
        });
      }

      // Defining an ID
      PolylineId id = PolylineId(polyId);

      // Initializing Polyline
      Polyline polyline = Polyline(
          polylineId: id,
          color: Colors.lightBlue[100],
          points: polylineCoordinates,
          width: 10);

      // adds polyline to the polylines to be displayed.
      polylines[polyId] = polyline;
      initialiseBounds();
    }
    // after all polylines are created set current polyline for navigation.
    setCurrentPolyline();
    notifyMapInfoChange();
  }

  initialiseBounds() {
    if (_currentRoute != null || _currentRoute == -1) {
      northEast = getNorthEastBound(_currentRoute);
      southWest = getSouthWestBound(_currentRoute);
    }
  }

  initialiseInfoVariables() {
    getDeliveryArrivalTime();
    updateDistanceRemaining();
    int del = _currentLeg + 1;
    delivery = "Delivery $del";
    directions = getDirection();
    deliveryTimeRemaining = getTimeToDelivery();
    deliveryAddress = getCurrentDeliveryAddress();
    directionIconPath = getDirectionIcon();
    notifyStepInfoChange();
    notifyDeliveryInfoChange();
  }

  initialiseDeliveryCircle() {
    Circle deliveryCircle = Circle(
      circleId: CircleId("$_currentRoute-$_currentLeg"),
      center: polylines["$_currentRoute"].points[0],
      fillColor: Color(0x2082fa9e),
      strokeColor: Colors.green[400],
      strokeWidth: 2,
      radius: 100.0,
    );
    circles.add(deliveryCircle);
    notifyCircleChange();
  }

  clearAllSetVariables() {
    directions = "";
    deliveryTimeRemaining = "";
    distance = 0;
    eta = "N/A";
    delivery = "N/A";
    deliveryAddress ="";
    directionIconPath = "assets/images/navigation_marker_white.png";
  }

  //__________________________________________________________________________________________________
  //                            Updates
  //__________________________________________________________________________________________________

  /*
   * Parameters: none
   * Returns: none
   * Description: Creates 2 new polylines with different colours to display that
   *              the driver is moving along the route between the points.
   */
  updateCurrentPolyline() {
    try {
      if (_deliveryRoutes == null || currentPolyline == null) {
        throw "Route error";
      }
      LatLng positionOnPoly = calculatePointOnPolyline();
      // remove previous position from polyline
      currentPolyline.points.removeAt(0);

      // determine where on polyline the driver is
      int newLength = 0;
      for (int i = 0; i < currentPolyline.points.length - 1; i++) {
        int dist1 = calculateDistanceBetween(currentPolyline.points[i + 1],
            LatLng(_position.latitude, _position.longitude));
        int dist2 = calculateDistanceBetween(
            currentPolyline.points[i], currentPolyline.points[i + 1]);
        if (dist2 > dist1) {
          newLength = i + 1;
        }
      }

      // remove any previous points
      newLength = currentPolyline.points.length - newLength;

      while (currentPolyline.points.length > 0 &&
          currentPolyline.points.length > newLength) {
        if(_lengthRemainingAfterNextStep == null){
          calculateNextStepPoint();
        }
        else if(_currentStep != _deliveryRoutes.routes[_currentRoute].legs[_currentLeg].steps.length -1 && _lengthRemainingAfterNextStep >= currentPolyline.points.length){
          _currentStep++;
          calculateNextStepPoint();
          // call update functions
          updateDirections();
          updateDeliveryTimeRemaining();
          updateETA();
          updateDirectionIconPath();

          notifyStepInfoChange();
        }
        if(currentPolyline.points.length == newLength + 1){
          previousPoint = currentPolyline.points.removeAt(0);
        }
        else{
          currentPolyline.points.removeAt(0);
        }
      }

      // re-add current position
      if(calculateDistanceBetween(currentPolyline.points[0], positionOnPoly) <
          calculateDistanceBetween(currentPolyline.points[0], previousPoint) * 2){
        currentPolyline.points.insert(0, positionOnPoly);
      }

      notifyMapInfoChange();
    } catch (error) {
      print("Failed to update current polyline.[$error]");
      return null;
    }
  }

  int calculateNextStepPoint(){
    LatLng nextStepStart = getStepStartLatLng(_currentRoute, _currentLeg, _currentStep);
    LatLng currentStepEnd;
    if(_currentStep > 0){
      currentStepEnd = getStepEndLatLng(_currentRoute, _currentLeg, _currentStep - 1);
    }
    else{
      currentStepEnd = getStepEndLatLng(_currentRoute, _currentLeg, _currentStep);
    }

    for (int i = 0; i < currentPolyline.points.length; i++) {
      if (_currentStep + 1 <= currentPolyline.points.length - 1 &&
          calculateDistanceBetween(
              currentPolyline.points[i],
              nextStepStart) <
              20) {
        _lengthRemainingAfterNextStep = currentPolyline.points.length - i;
        return _lengthRemainingAfterNextStep;
      } else if (_currentStep - 1 >= 0 &&
          _currentStep + 1 <=
              _deliveryRoutes.routes[_currentRoute].legs[_currentLeg].steps.length - 1 &&
          calculateDistanceBetween(
              currentPolyline.points[i],
              currentStepEnd) < 20) {
        _lengthRemainingAfterNextStep = currentPolyline.points.length - i;
        return _lengthRemainingAfterNextStep;
      }
    }
    return -1;
  }

  String updateDistanceRemaining() {
    try {
      if (polylines == null) {
        throw "No route set";
      }
      if (currentPolyline == null) {
        throw "No current route set";
      }

      // get total distance left to travel
      int totalDistance = 0;
      for (int i = 0; i < currentPolyline.points.length - 1; i++) {
        totalDistance += calculateDistanceBetween(
            currentPolyline.points[i], currentPolyline.points[i + 1]);
      }
      for (int i = 0; i < polylines["$_currentRoute"].points.length - 1; i++) {
        totalDistance += calculateDistanceBetween(
            polylines["$_currentRoute"].points[i],
            polylines["$_currentRoute"].points[i + 1]);
      }

      // format distance to km
      if (totalDistance > 1000) {
        int km = 0;
        int m = (totalDistance / 100).round() * 100;
        while (m > 1000) {
          m -= 1000;
          km += 1;
        }
        m = (m / 100).round();
        totalDistance = (totalDistance / 10).round() * 10;
        distance = totalDistance;
        distanceString = "$km,$m km";
        notifyDistanceChange();
        return distanceString;
      }

      totalDistance = (totalDistance / 10).round() * 10;
      distance = totalDistance;
      distanceString = "$totalDistance m";
      notifyDistanceChange();

      return distanceString;
    } catch (error) {
      print("Failed to update distance-eta.[$error]");
      return "N/A";
    }
  }

  String updateETA(){
    if (_deliveryRoutes == null) {
      return null;
    }

    getDeliveryArrivalTime();
    return eta;
  }

  String updateDirectionIconPath(){
    if (_deliveryRoutes == null) {
      return null;
    }

    getDirectionIcon();
    return directionIconPath;
  }

  String updateDeliveryTimeRemaining() {
    if (_deliveryRoutes == null) {
      return null;
    }
    int totalTime =
    _deliveryRoutes.getDeliveryDuration(_currentRoute, _currentLeg);
    for (int i = 0; i < _currentStep; i++) {
      totalTime -=
          _deliveryRoutes.getStepDuration(_currentRoute, _currentLeg, i);
    }

    totalTime = (totalTime / 60).ceil();

    deliveryTimeRemaining = "$totalTime min";

    return deliveryTimeRemaining;
  }

  String updateDirections() {
    if (_deliveryRoutes == null) {
      return null;
    }
    getDirectionIcon();
    directions = getDirection();

    return directions;
  }

  //__________________________________________________________________________________________________
  //                            Setters
  //__________________________________________________________________________________________________

  setCurrentPolyline() {
    try {
      if (_deliveryRoutes == null) {
        return;
      }

      if (_lengthRemainingAfterNextDelivery == null) {
        calculateNextDeliveryPoint();
      }

      if (_lengthRemainingAfterNextDelivery == null) {
        throw "Delivery point not found";
      }

      int lengthRemaining = polylines["$_currentRoute"].points.length -
          _lengthRemainingAfterNextDelivery;

      List<LatLng> currentPoints = [];
      polylines["current"] = null;

      while (lengthRemaining > 0) {
        currentPoints.add(polylines["$_currentRoute"].points.removeAt(0));
        lengthRemaining -= 1;
      }

      currentPolyline = null;
      currentPolyline = Polyline(
          polylineId: PolylineId("current"),
          points: currentPoints,
          color: Colors.blueAccent,
          width: 8,
          zIndex: 1000
      );

      polylines["current"] = currentPolyline;
    } catch (error) {
      print("Failed to set current polyline.[$error]");
      return;
    }
    //currentPolyline = polylines["$_currentRoute-$_currentLeg"];
  }

  setCurrentRoute() async {
    _currentRoute = int.parse(await _storage.read(key: 'current_route') != null
        ? await _storage.read(key: 'current_route')
        : -1);
  }

  setPreviousPoint(LatLng point){
    previousPoint = point;
  }

  //__________________________________________________________________________________________________
  //                            Observers
  //__________________________________________________________________________________________________

  subscribe(dynamic subscriber){
    subscribers.add(subscriber);
  }

  unsubscribe(dynamic subscriber){
    subscribers.remove(subscriber);
  }

  notifyStepInfoChange(){
    notifyDirectionChange();
    notifyTimeRemainingChange();
    notifyETAChange();
    notifyDirectionIconPathChange();
  }

  notifyDeliveryInfoChange(){
    notifyDeliveryChange();
    notifyDeliveryAddressChange();
  }

  notifyMapInfoChange(){
    notifyPolylineChange();
    notifyMarkerChange();
  }

  notifyDirectionChange(){
    subscribers.forEach((element) {
      element.setDirection(directions);
    });
  }

  notifyTimeRemainingChange(){
    subscribers.forEach((element) {
      element.setTimeRemaining(deliveryTimeRemaining);
    });
  }

  notifyDistanceChange(){
    subscribers.forEach((element) {
      element.setDistance(distanceString);
    });
  }

  notifyETAChange(){
    subscribers.forEach((element) {
      element.setETA(eta);
    });
  }

  notifyDeliveryChange(){
    subscribers.forEach((element) {
      element.setDelivery(delivery);
    });
  }

  notifyDeliveryAddressChange(){
    subscribers.forEach((element) {
      element.setDeliveryAddress(deliveryAddress);
    });
  }

  notifyDirectionIconPathChange(){
    subscribers.forEach((element) {
      element.setDirectionIconPath(directionIconPath);
    });
  }

  notifyPolylineChange(){
    subscribers.forEach((element) {
      element.setPolylines(polylines);
    });
  }

  notifyCircleChange(){
    subscribers.forEach((element) {
      element.setCircles(circles);
    });
  }

  notifyMarkerChange(){
    subscribers.forEach((element) {
      element.setMarkers(markers);
    });
  }

  notifyNearDelivery(){
    subscribers.forEach((element) {
      element.setNearDelivery(true);
    });
  }

  notifyNotNearDelivery(){
    subscribers.forEach((element) {
      element.setNearDelivery(false);
    });
  }

  //__________________________________________________________________________________________________
  //                            Getters
  //__________________________________________________________________________________________________

  bool isRouteInitialised(){
    return _routesInitialised;
  }

  Position getPosition(){
    return _position;
  }

  int getRoute() {
    return _currentRoute;
  }

  int getLeg() {
    return _currentLeg;
  }

  int getStep() {
    return _currentStep;
  }

  DeliveryRoute getDeliveryRoutes(){
    return _deliveryRoutes;
  }

  /*
   * Parameters: none
   * Returns: String
   * Description: Gets street names for directions.
   *              \u003c = opening tag and \u003e = closing tags
   */
  String getDirection() {
    if (_deliveryRoutes == null) {
      return "LOADING...";
    }
    return _deliveryRoutes.getHTMLInstruction(
        _currentRoute, _currentLeg, _currentStep);
  }

  String getDirectionIcon() {
    String path = "assets/images/";
    if (_deliveryRoutes == null || atDelivery) {
      path += "navigation_marker_white.png";
      directionIconPath = path;
      return directionIconPath;
    }

    String direction =
    _deliveryRoutes.getManeuver(_currentRoute, _currentLeg, _currentStep);

    switch (direction) {
      case "turn-right":
        path += "right_turn_arrow";
        break;
      case "roundabout-right":
        path += "right_turn_arrow";
        break;
      case "turn-left":
        path += "left_turn_arrow";
        break;
      case "roundabout-left":
        path += "left_turn_arrow";
        break;
      default:
        path += "straight_arrow";
    }

    //chose color
    path += "_white.png";
    directionIconPath = path;

    return directionIconPath;
  } // gets icon to display directions such as right arrow for turn right

  String getTimeToDelivery() {
    if (_deliveryRoutes == null) {
      return null;
    }

    int duration =
    (_deliveryRoutes.getDeliveryDuration(_currentRoute, _currentLeg) / 60)
        .ceil();

    return "$duration min";
  } // gets arrival time

  int getStepDistance() {
    if (_deliveryRoutes == null) {
      return null;
    }
    return (_deliveryRoutes.getStepDistance(
        _currentRoute, _currentLeg, _currentStep) /
        10).round() * 10;
  }

  int getRouteDistance(int route) {
    if (_deliveryRoutes == null) {
      return null;
    }

    return (_deliveryRoutes.getRouteDistance(route) / 10)
            .round() * 10;

  }

  int getRouteDuration(int route){
    if (_deliveryRoutes == null) {
      return null;
    }

    return _deliveryRoutes.getRouteDuration(route);
  }

  String getDeliveryDistance() {
    if (_deliveryRoutes == null) {
      return null;
    }

    int distance =
        (_deliveryRoutes.getDeliveryDistance(_currentRoute, _currentLeg) / 10)
            .round() * 10;

    if (distance > 1000) {
      int km = 0;
      int m = (distance / 100).round() * 100;
      while (m > 1000) {
        m -= 1000;
        km += 1;
      }
      m = (m / 100).round();

      return "$km,$m km";
    }

    return "$distance m";
  }

  String getDeliveryArrivalTime() {
    if (_deliveryRoutes == null) {
      return null;
    }

    int arrivalTime =
    (_deliveryRoutes.getDeliveryDuration(_currentRoute, _currentLeg) / 60)
        .ceil();
    int hours = 0;
    int minutes = 0;
    int temp = arrivalTime;
    if (arrivalTime > 60) {
      while (temp > 60) {
        temp -= 60;
        hours += 1;
      }
    }

    DateTime deliveryTimeStamp = DateTime.now();
    minutes += temp;
    deliveryTimeStamp =
        deliveryTimeStamp.add(Duration(hours: hours, minutes: minutes));
    hours = deliveryTimeStamp.hour;
    minutes = deliveryTimeStamp.minute;
    String hourString;
    String minuteString;

    if (hours < 10) {
      hourString = "0$hours";
    } else {
      hourString = "$hours";
    }

    if (minutes < 10) {
      minuteString = "0$minutes";
    } else {
      minuteString = "$minutes";
    }
    eta = "$hourString:$minuteString";

    return eta;
  }

  int getRemainingDeliveries() {
    if (_deliveryRoutes == null) {
      return null;
    }
    return _deliveryRoutes.routes[_currentRoute].legs.length - _currentLeg;
  }

  int getTotalDeliveries() {
    if (_deliveryRoutes == null) {
      return 0;
    }
    return _deliveryRoutes.getTotalDeliveries();
  }

    String getCurrentDeliveryAddress() {
      if (_deliveryRoutes == null) {
        return "";
      } else {
        String address =
        _deliveryRoutes.getDeliveryAddress(_currentRoute, _currentLeg);
        List<String> temp = address.split(",");
        address = temp[0];
        return address;
      }
    }

    String getDeliveryAddress(int leg) {
      if (_deliveryRoutes == null || _currentRoute == -1) {
        return "";
      } else {
        String address = _deliveryRoutes.getDeliveryAddress(_currentRoute, leg);
        return address;
      }
    }

    int getNumberOfDeliveries() {
      if (_deliveryRoutes == null || _currentRoute == -1) {
        return 0;
      }
      return _deliveryRoutes.routes[_currentRoute].legs.length;
    }

    LatLng getStepStartLatLng(int route, int leg, int step) {
      if (_deliveryRoutes == null) {
        return null;
      }
      return _deliveryRoutes.getStepStartLatLng(route, leg, step);
    }

    LatLng getStepEndLatLng(int route, int leg, int step) {
      if (_deliveryRoutes == null) {
        return null;
      }
      return _deliveryRoutes.getStepEndLatLng(route, leg, step);
    }

    LatLng getNorthEastBound(int route) {
      if (_deliveryRoutes == null) {
        return null;
      }
      return _deliveryRoutes.getNorthEastBound(route);
    }

    LatLng getSouthWestBound(int route) {
      if (_deliveryRoutes == null) {
        return null;
      }
      return _deliveryRoutes.getSouthWestBound(route);
    }

    LatLng getNextDeliveryLocation() {
      if (_deliveryRoutes == null || _currentRoute < 0 ||
          _currentRoute > _deliveryRoutes.routes.length || _currentLeg < 0
          || _currentLeg >= _deliveryRoutes.routes[_currentRoute].legs.length) {
        return null;
      }
      return _deliveryRoutes.getNextDeliveryLocation(
          _currentRoute, _currentLeg);
    }

    Future<int> getChosenRoute() async {
      return int.parse(await _storage.read(key: 'current_route'));
    }

    //__________________________________________________________________________________________________
    //                            Calculation functions
    //__________________________________________________________________________________________________

    /*
   * Author: Jordan Nijs
   * Parameters: none
   * Returns: int
   * Description: Uses a current position to determine distance away from next point.
   */
    int calculateDistanceBetween(LatLng currentPosition, LatLng lastPosition) {
      double p = 0.017453292519943295;
      double a = 0.5 -
          cos((currentPosition.latitude - lastPosition.latitude) * p) / 2 +
          cos(lastPosition.latitude * p) *
              cos(currentPosition.latitude * p) *
              (1 -
                  cos((currentPosition.longitude - lastPosition.longitude) *
                      p)) /
              2;
      return (12742 * asin(sqrt(a)) * 1000).round();
    }

    /*
   * Author: dammy_ololade (https://github.com/Dammyololade/flutter_polyline_points/blob/master/lib/src/network_util.dart)
   * Parameters: Google Encoded String
   * Returns: List
   * Description: Decode the google encoded string using Encoded Polyline Algorithm Format.
   *              For more info about the algorithm check  https://developers.google.com/maps/documentation/utilities/polylinealgorithm
   */
    List<PointLatLng> decodeEncodedPolyline(String encoded) {
      List<PointLatLng> poly = [];
      int index = 0,
          len = encoded.length;
      int lat = 0,
          lng = 0;

      while (index < len) {
        int b,
            shift = 0,
            result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlat = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lat += dlat;

        shift = 0;
        result = 0;
        do {
          b = encoded.codeUnitAt(index++) - 63;
          result |= (b & 0x1f) << shift;
          shift += 5;
        } while (b >= 0x20);
        int dlng = ((result & 1) != 0 ? ~(result >> 1) : (result >> 1));
        lng += dlng;
        PointLatLng p =
        new PointLatLng((lat / 1E5).toDouble(), (lng / 1E5).toDouble());
        poly.add(p);
      }
      return poly;
    }

    LatLng calculatePointOnPolyline() {
      if (currentPolyline == null) {
        return null;
      }

      /*
      TODO
        - Fix this shit
       */

      LatLng start = previousPoint;
      if(start == null){
        start = currentPolyline.points[0];
      }
      LatLng end = currentPolyline.points[1];

      // work out perpendicular intersect of line between polyline points and line that goes through current position.
      double m =
          (end.longitude - start.longitude) / (end.latitude - start.latitude);
      double b = start.longitude - (m * start.latitude);
      double perpendicularM = -1 * (1 / m);
      double perpendicularB =
          _position.longitude - (perpendicularM * _position.latitude);

      double shouldBeAtLat = (b - perpendicularB) / (perpendicularM - m);
      double shouldBeAt = m * (shouldBeAtLat) + b;

      LatLng currentPoint = LatLng(shouldBeAtLat, shouldBeAt);

      return currentPoint;
    }

    int calculateNextDeliveryPoint() {
      LatLng delivery = getNextDeliveryLocation();
      for (int i = 0; i < polylines["$_currentRoute"].points.length; i++) {
        if (calculateDistanceBetween(
            delivery, polylines["$_currentRoute"].points[i]) <
            2) {
          _lengthRemainingAfterNextDelivery =
              polylines["$_currentRoute"].points.length - i;
          return _lengthRemainingAfterNextDelivery;
        }
      }
      return null;
    }

    //__________________________________________________________________________________________________
    //                            Delivery management
    //__________________________________________________________________________________________________

    bool isNearDelivery() {
      try {
        if(currentPolyline.points.length < 2){
          LatLng current = LatLng(_position.latitude, _position.longitude);
          print(getNextDeliveryLocation());
          if(calculateDistanceBetween(current, getNextDeliveryLocation()) < 40){
            nearDelivery = true;
            notifyNearDelivery();
            showDeliveryRadiusOnMap();
            isAtDelivery();
            return true;
          }
          else{
            throw "Not enough points on polyline to calculate";
          }
        }
        int dist = calculateDistanceBetween(
            currentPolyline.points[0], currentPolyline.points.last);
        if (dist < 50) {
          nearDelivery = true;
          notifyNearDelivery();
          isAtDelivery();
        } else {
          nearDelivery = false;
          notifyNotNearDelivery();
        }
        showDeliveryRadiusOnMap();
        return nearDelivery;
      } catch (error) {
        print("Failed to determine if near delivery.[$error]");
        nearDelivery = false;
        notifyNotNearDelivery();
        return nearDelivery;
      }
    }

    showDeliveryRadiusOnMap() {
      if (nearDelivery) {
        initialiseDeliveryCircle();
      } else {
        circles = {};
      }
      notifyCircleChange();
    }

    bool isAtDelivery() {
      if (currentPolyline.points.length < 3 || calculateDistanceBetween(currentPolyline.points[0], currentPolyline.points.last) < 40) {
        notifyNearDelivery();
        atDelivery = true;
      }
      return atDelivery;
    }

    sendDeliveryAPICall() async {
      ApiHandler api = ApiHandler();

      List<routeModel.Route> routes = await api.getUncalculatedRoute();
      if (routes == null) {
        return;
      }
      for (int j = 0; j < routes[_currentRoute].locations.length; j++) {
        if (calculateDistanceBetween(
            currentPolyline.points.last,
            LatLng(double.parse(routes[_currentRoute].locations[j].latitude),
                double.parse(routes[_currentRoute].locations[j].longitude))) <
            1) {
          if (_currentLeg == _deliveryRoutes.routes[_currentRoute].legs.length - 1) {
            sendCompletedRouteAPICall();
            return;
          }
          await api.completeDelivery(
              routes[_currentRoute].locations[j].locationID, _position);
        }
      }
    }

    sendCompletedRouteAPICall() async {
      if(_currentLeg != _deliveryRoutes.routes.length -1){
        return;
      }
      ApiHandler api = ApiHandler();
      var id = await api.getActiveRouteID(_currentRoute);
      api.completeRoute(id, _position);
    }

    moveToNextDelivery() {
      if(_currentLeg >= _deliveryRoutes.routes[_currentRoute].legs.length - 1){
        clearAllSetVariables();
        currentPolyline = null;
        polylines = {};
        markers = {};
        circles = {};
        _currentRoute = -1;
        _currentLeg = 0;
        _currentStep = 0;
        nearDelivery = false;
        atDelivery = false;
        notifyCircleChange();
        notifyNotNearDelivery();
        notifyMapInfoChange();
        notifyDeliveryInfoChange();
        notifyDeliveryChange();
        return;
      }

      _currentLeg += 1;
      _currentStep = 0;
      nearDelivery = false;
      atDelivery = false;
      showDeliveryRadiusOnMap();
      markers.remove(markers.first);
      calculateNextDeliveryPoint();
      currentPolyline = null;
      setCurrentPolyline();
      clearAllSetVariables();
      initialiseInfoVariables();
      notifyDeliveryChange();
    }

    //__________________________________________________________________________________________________
    //                            Main Function
    //__________________________________________________________________________________________________

    /*
   * Parameters: Position
   * Returns: int
   * Description: Navigation function that implements all the required steps for navigation.
   */
    navigate(Position currentPosition, BuildContext context) async {
      /*
    - set current location
    - find the current point
    - check if on route -> if not start creating black poly
    - check if close to step or leg
    - set step/leg as required
    - update current polyline
    - update the info vars for map
     */

      if (_deliveryRoutes == null) {
        initialiseRoutes();
        return;
      }

      if (_notificationManager == null) {
        _notificationManager = LocalNotifications();
        initialiseNotifications(context);
      }
      if (!_notificationManager.initialised) {
        _notificationManager.initializing(context);
      }

      if (_currentRoute == -1) {
        String currentRoute = await _storage.read(key: 'current_route');
        if (currentRoute == null) {
          return;
        }
        int route = int.parse(currentRoute);
        if (route == null || route == -1) {
          return;
        }
        _currentRoute = route;
      }

      if (polylines == null ||
          polylines.length == 0 ||
          markers == null ||
          markers.length == 0) {
        initialisePolyPointsAndMarkers(_currentRoute);
      }

      _position = currentPosition;
      _abnormalityService.setCurrentLocation(currentPosition);
      _notificationManager.setContext(context);

      // safety checks
      if (currentPolyline == null) {
        setCurrentPolyline();
        return;
        // uncomment when not using replacement functions from abnormality service
        //_abnormalityService.getSpeedLimit(currentPolyline.points);
      }
      if (directions == null ||
          distanceString == null ||
          delivery == null ||
          deliveryAddress == null ||
          directionIconPath == null) {

        initialiseInfoVariables();
        return;
      }
      if (_lengthRemainingAfterNextDelivery == null) {
        calculateNextDeliveryPoint();
        if (_lengthRemainingAfterNextDelivery == null) {
          print("Dev: Couldn't find next delivery Point");
          return;
        }
      }
      if (currentPolyline.points.length < 10) {
        isNearDelivery();
      }

      // if the driver is not at a delivery point
      if (!nearDelivery) {
        // check if on the route
        bool onRoute = false;

        if (!_abnormalityService.offRoute(currentPolyline)) {
          onRoute = true;
        }

        if (onRoute) {
          updateCurrentPolyline();
        } else {
          // making sure only one notification gets sent.
          if (!_abnormalityService.getStillOffRoute()) {
            if(currentPolyline.points.length > 0){
              currentPolyline.points.removeAt(0);
            }
            _notificationManager.showNotifications(
                _abnormalityHeaders["offroute"],
                _abnormalityMessages["offroute"]);
          }
          //start marking the route he followed.
        }

        if (_abnormalityService.stoppingTooLong()) {
          _notificationManager.showNotifications(
              _abnormalityHeaders["stopping_too_long"],
              _abnormalityMessages["stopping_too_long"]);
        }

        /*
       Temp functions being called to be replaced before actual deployment.
       For more information about this see the AbnormalityService class as well
       as the
     */
//        if (_abnormalityService.drivingTooSlowTemp()) {
//          //_notificationManager.report = "slow";
//          //_notificationManager.showNotifications(_abnormalityHeaders["driving_too_slow"], _abnormalityMessages["driving_too_slow"]);
//        }
        //update info
        updateDeliveryTimeRemaining();
        updateDistanceRemaining();
        updateDirections();
      } else {
        // if the driver is at a delivery point
        updateCurrentPolyline();
      }

      // General abnormalities
      if (_abnormalityService.suddenStop()) {
        _notificationManager.showNotifications(
            _abnormalityHeaders["sudden_stop"],
            _abnormalityMessages["sudden_stop"]);
      }
      /*
    Temp functions being called to be replaced before actual deployment.
    For more information about this see the AbnormalityService class as well
    as the
    */
      if (_abnormalityService.isSpeedingTemp()) {
        _notificationManager.showNotifications(
              _abnormalityHeaders["speeding"],
              _abnormalityMessages["speeding"]);
      }
    }
  }
/*
 TODO
  navigation
  - update storage variables
  - when routes are completed, delete file clear uncalculated and calculating
 */
