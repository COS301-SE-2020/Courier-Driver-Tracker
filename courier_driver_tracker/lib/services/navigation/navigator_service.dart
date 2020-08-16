import 'dart:math';
import 'package:courier_driver_tracker/services/abnormality/abnormality_service.dart';
import 'package:courier_driver_tracker/services/file_handling/json_handler.dart';
import 'package:courier_driver_tracker/services/navigation/delivery_route.dart';
import 'package:courier_driver_tracker/services/notification/local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter_polyline_points/flutter_polyline_points.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class NavigatorService{

  DeliveryRoute _deliveryRoutes;
  int _currentRoute;
  int _currentLeg;
  int _currentStep;
  int _currentPoint;
  String jsonFile;
  LocalNotifications _notificationManager = LocalNotifications();
  AbnormalityService _abnormalityService = AbnormalityService();
  Position _position;
  bool _doneWithDelivery;

  // Map polylines and markers
  Map<String, Polyline> polylines = {};
  Polyline currentPolyline;
  Polyline splitPolylineBefore;
  List<LatLng> splitPolylineCoordinatesBefore;
  Polyline splitPolylineAfter;
  List<LatLng> splitPolylineCoordinatesAfter;
  Set<Marker> markers = {};

  // Notifications
  Map<String, String> _abnormalityHeaders =
  {
    "offroute" : "Going Off Route!"
  };
  Map<String, String> _abnormalityMessages =
  {
    "offroute" : "You are going off the prescribed route."
  };

  NavigatorService({this.jsonFile}){
    _currentRoute = 0;
    _currentLeg = 0;
    _currentStep = 0;
    _currentPoint = 0;
    getRoutes();
    setInitialPolyPointsAndMarkers(_currentRoute);
  }

  /*
   * Author: Gian Geyser
   * Parameters: Position
   * Returns: int
   * Description: Navigation function that implements all the required steps for navigation.
   */
  navigate(Position currentPosition){
    /*
    - set current location
    - find the current point
    - check if on route -> if not start creating black poly
    - check if close to step or leg
    - set step/leg as required
    - update current polyline
    - update the info vars for map
     */

    _position = currentPosition;
    _abnormalityService.setCurrentLocation(currentPosition);
    if(currentPolyline == null){
      setCurrentPolyline();
    }
    if(splitPolylineAfter == null || splitPolylineBefore == null){
      setCurrentSplitPolylines();
    }
    findCurrentPoint();
    LatLng current = currentPolyline.points[_currentPoint];
    LatLng next;
    if(_currentPoint < currentPolyline.points.length -1){
      next = currentPolyline.points[_currentPoint + 1];
    }
    else if(_currentPoint == currentPolyline.points.length - 1 && _currentStep == _deliveryRoutes.routes[_currentRoute].legs[_currentLeg].steps.length - 1){
      int nextLeg = _currentLeg + 1;
      next = getPolyline("$_currentRoute-$nextLeg-0").points[0];
    }
    else{
      int nextStep = _currentStep + 1;
      next = getPolyline("$_currentRoute-$_currentLeg-$nextStep").points[0];
    }
    if(!_abnormalityService.offRoute(current, next)){
      moveToNextStep();
      moveToNextLeg();
      // call abnormalities

      // set info vars
    }
    else{
      _notificationManager.createState().showNotifications(_abnormalityHeaders["offroute"], _abnormalityMessages["offroute"]);
      // start marking the route he followed.
    }
  }

  /*
   * Author: Jordan Nijs
   * Parameters: none
   * Returns: int
   * Description: Uses a current position to determine distance away from next point.
   */
  int calculateDistanceBetween(Position currentPosition, Position lastPosition){
    double p = 0.017453292519943295;
    double a = 0.5 - cos((currentPosition.latitude - lastPosition.latitude) * p)/2 +
        cos(lastPosition.latitude * p) * cos(currentPosition.latitude * p) *
            (1 - cos((currentPosition.longitude - lastPosition.longitude) * p))/2;
    return 12742 * asin(sqrt(a)) * 1000 as int;
  }

  /*
   * Author: Gian Geyser
   * Parameters: none
   * Returns: none
   * Description: Determines the point within the step where the driver is at.
   *              Used to split the polyline for UI purposes.
   */
  findCurrentPoint(){
    for(int i = 0; i < splitPolylineCoordinatesAfter.length -1; i++){
      double d1 = sqrt(pow((_position.latitude - splitPolylineCoordinatesAfter[i].latitude),2) + pow(_position.longitude - splitPolylineCoordinatesAfter[i].longitude,2));
      double d2 = sqrt(pow((splitPolylineCoordinatesAfter[i+1].latitude - splitPolylineCoordinatesAfter[i].latitude),2) + pow(splitPolylineCoordinatesAfter[i+1].longitude - splitPolylineCoordinatesAfter[i].longitude,2));

      if(d1 < d2){
        _currentPoint = i;
        return;
      }
    }
  }

  bool passedStepPoint(){
    int nextStep = _currentStep + 1;
    LatLng lastPoint = currentPolyline.points.last;
    Polyline poly = getPolyline("$_currentRoute-$_currentLeg-$nextStep");
    LatLng nextPoint;
    if(poly != null){
      nextPoint = poly.points.first;
    }
    else{
      return false;
    }
    double d1 = sqrt(pow((_position.latitude - lastPoint.latitude),2) + pow((_position.longitude - lastPoint.longitude),2));
    double d2 = sqrt(pow((nextPoint.latitude - lastPoint.latitude),2) + pow(nextPoint.longitude - lastPoint.longitude,2));

    if(d1 < d2){
      return true;
    }
    else{
      return false;
    }
  }

  bool reachedStepPoint(){
    Polyline poly = getPolyline("$_currentRoute-$_currentLeg-$_currentStep");
    if(poly != null && _currentPoint == poly.points.length - 1){
      polylines["$_currentRoute-$_currentLeg-$_currentStep"] = poly;
      return true;
    }
    else{
      return false;
    }
  }

  moveToNextStep(){
    if(passedStepPoint()){
      _currentStep += 1;
      updatePreviousStepPolyline();
      setCurrentPolyline();
      setCurrentSplitPolylines();
    }
    else{
      updateCurrentPolyline();
    }
  }

  moveToNextLeg(){
    if(reachedStepPoint() && _currentStep == _deliveryRoutes.routes[_currentRoute].legs[_currentLeg].steps.length - 1 && _doneWithDelivery){
      _currentLeg += 1;
      _currentStep = 0;
      updatePreviousStepPolyline();
      setCurrentPolyline();
      setCurrentSplitPolylines();
      _doneWithDelivery = false;
    }

  }


  /*
   * Author: Gian Geyser
   * Parameters: none
   * Returns: none
   * Description: Creates 2 new polylines with different colours to display that
   *              the driver is moving along the route between the points.
   */
  updateCurrentPolyline(){
    // remove previous position from before and after polyline
    splitPolylineCoordinatesBefore.removeLast();
    splitPolylineCoordinatesAfter.removeAt(0);

    while(splitPolylineCoordinatesBefore.length < _currentPoint){
      splitPolylineCoordinatesBefore.add(splitPolylineCoordinatesAfter.removeAt(0));
    }
    splitPolylineCoordinatesAfter.insertAll(0,[LatLng(_position.latitude, _position.longitude)]);
    splitPolylineCoordinatesBefore.add(LatLng(_position.latitude, _position.longitude));
    splitPolylineBefore = Polyline(
      polylineId: splitPolylineBefore.polylineId,
      color: Colors.purple[200],
      points: splitPolylineCoordinatesBefore,
      width: 5
    );
    splitPolylineAfter = Polyline(
      polylineId: splitPolylineAfter.polylineId,
      color: Colors.purple,
      points: splitPolylineCoordinatesAfter,
      width: 5
    );
  }

  /*
   * Author: Gian Geyser
   * Parameters: none
   * Returns: none
   * Description: After driver has reached the next step update the previous
   *              polyline to show the step has been completed.
   */
  updatePreviousStepPolyline(){
    // remove before and after split polys
    polylines.remove(splitPolylineBefore.polylineId);
    polylines.remove(splitPolylineAfter.polylineId);

    // add the delivery route again with lighter colour
    polylines[currentPolyline.polylineId.value] = Polyline(
      polylineId: currentPolyline.polylineId,
      color: Colors.purple[200],
      points: currentPolyline.points,
      width: 5
    );
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
    int index = 0, len = encoded.length;
    int lat = 0, lng = 0;

    while (index < len) {
      int b, shift = 0, result = 0;
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


  /*
  *     ---- Getters ----
  */
  DeliveryRoute getDeliveryRoute(){
    return _deliveryRoutes;
  }

  int getStep(){
    return _currentStep;
  }

  int getLeg(){
    return _currentLeg;
  }

  int getDelivery(){
    return _currentRoute;
  }

  Polyline getPolyline(String ID){
    return polylines.remove(ID);
  }

  /*
   * Author: Gian Geyser
   * Parameters: none
   * Returns: none
   * Description: Turns json from saved file into DeliveryRoute object.
   *
   */
  getRoutes()  async {
    JsonHandler handler = JsonHandler();
    Map<String, dynamic> json = await handler.parseJson(jsonFile);
    _deliveryRoutes = DeliveryRoute.fromJson(json);
  }

  String getNextDirection(){
    return _deliveryRoutes.getHTMLInstruction(_currentRoute, _currentLeg, _currentStep + 1);
  } // gets the next directions

  /*
   * Author: Gian Geyser
   * Parameters: none
   * Returns: String
   * Description: Gets street names for directions.
   *              \u003c = opening tag and \u003e = closing tags
   */
  String getDirection(){
    return _deliveryRoutes.getHTMLInstruction(_currentRoute, _currentLeg, _currentStep);
  }

  getDirectionIcon(){
    String direction = _deliveryRoutes.getManeuver(_currentRoute, _currentLeg, _currentStep);
    switch(direction){
      case "turn-right":
        break;
      case "roundabout-right":
        break;
      case "turn-left":
        break;
      case "roundabout-left":
        break;
      default:

    }

  } // gets icon to display directions such as right arrow for turn right

  int getArrivalTime(){
    return _deliveryRoutes.getDuration(_currentRoute, _currentLeg, _currentStep);
  } // gets arrival time

  int getDistance(){
    return _deliveryRoutes.getDistance(_currentRoute, _currentLeg, _currentStep);
  }

  getDeliveryArrivalTime(){
    return _deliveryRoutes.getDeliveryDuration(_currentRoute, _currentLeg);
  } // gets arrival time
  getDeliveryDistance(){
    return _deliveryRoutes.getDeliveryDistance(_currentRoute, _currentLeg);
  }

  int getRemainingDeliveries(){
    return getTotalDeliveries() - _currentRoute -1;
  }

  int getTotalDeliveries(){
    return _deliveryRoutes.getTotalDeliveries();
  }


  /*
  *   ---- Setters ----
  */
  setRouteFilename(String filename){
    jsonFile = filename;
  }

  updateCurrentPosition(Position position){
    _position = position;
  }

  setInitialPolyPointsAndMarkers(int route) async {
    if(_deliveryRoutes == null){
      await getRoutes();
    }
    for(int leg = 0; leg < _deliveryRoutes.routes[route].legs.length; leg++){
      int delivery = leg + 1;
      Marker marker = Marker(
        markerId: MarkerId('$route-$leg'),
        position: LatLng(
          _deliveryRoutes.routes[route].legs[leg].endLocation.lat,
          _deliveryRoutes.routes[route].legs[leg].endLocation.lng,
        ),
        infoWindow: InfoWindow(
          title: 'Delivery $delivery',
          snippet: _deliveryRoutes.routes[route].legs[leg].endAddress,
        ),
        icon: BitmapDescriptor.defaultMarker,
      );
      markers.add(marker);
      for(int step = 0; step < _deliveryRoutes.routes[route].legs[leg].steps.length; step++){
        List<LatLng> polylineCoordinates = [];
        String polyId = "$route-$leg-$step";

        // get polyline points from DeliveryRoute in navigator service
        List<PointLatLng> result = decodeEncodedPolyline(_deliveryRoutes.routes[route].legs[leg].steps[step].polyline.points);

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
          color: Colors.purple,
          points: polylineCoordinates,
          width: 5,
        );

        // adds polyline to the polylines to be displayed.
        polylines[polyId] = polyline;
      }
    }
    // after all polylines are created set current polyline and split it for navigation.
  }

  setCurrentPolyline(){
    currentPolyline = polylines.remove("$_currentRoute-$_currentLeg-$_currentStep");
  }

  setCurrentSplitPolylines(){
    if(_position == null){
      return;
    }

    splitPolylineCoordinatesBefore = [];
    splitPolylineCoordinatesAfter = [];
    splitPolylineCoordinatesBefore.add(LatLng(_position.latitude, _position.longitude));
    splitPolylineCoordinatesAfter.add(LatLng(_position.latitude, _position.longitude));
    splitPolylineCoordinatesAfter.addAll(currentPolyline.points);

    PolylineId polyBeforeID = PolylineId("$_currentRoute-$_currentLeg-$_currentStep-before");
    PolylineId polyAfterID = PolylineId("$_currentRoute-$_currentLeg-$_currentStep-after");

    splitPolylineBefore = Polyline(
        polylineId: polyBeforeID,
        color: Colors.purple[200],
        points: splitPolylineCoordinatesBefore,
        width: 5
    );
    splitPolylineAfter = Polyline(
        polylineId: polyAfterID,
        color: Colors.purple,
        points: splitPolylineCoordinatesAfter,
        width: 5
    );

    // add split polys to the polylines
    polylines[polyBeforeID.value] = splitPolylineBefore;
    polylines[polyAfterID.value] = splitPolylineAfter;
  }
}

/*
TODO
  - write function to handle the navigation checks
  - if off route add black poly where they drive
  - UI design and testing
  - integrate API
  - integrate abnormailties
  - integrate notifications
  + add icon to notifications
 */