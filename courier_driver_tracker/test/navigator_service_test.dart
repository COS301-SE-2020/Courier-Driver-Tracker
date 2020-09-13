import 'package:courier_driver_tracker/services/location/google_maps.dart';
import 'package:courier_driver_tracker/services/navigation/delivery_route.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:courier_driver_tracker/services/navigation/navigation_service.dart';
import 'package:courier_driver_tracker/services/file_handling/json_handler.dart';
import 'package:geolocator/geolocator.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';


Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();
  String filename = "route.json";
  Map<String, dynamic> json = await JsonHandler().parseJson(filename);
  NavigationService navigatorService;
  BuildContext context;

  test("Initialisation Test",() async {
    bool created;
    navigatorService = NavigationService(context: context);
    if(navigatorService is NavigationService){
      created  = true;
    }
    else{
      created = false;
    }
    expect(created, true);
  });

  test("DeliveryRoute Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService();
      await navigatorService.getRoutes();
    }
    bool created;

    if(navigatorService.NavigationService() is DeliveryRoute){
      created  = true;
    }
    else{
      created = false;
    }
    expect(created, true);
  });

  test("getDirection Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }

    currentPosition = Position(
      latitude: json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep()]["start_location"]["lat"],
      longitude: json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep()]["start_location"]["lng"],
      accuracy: 10.0,
      speed: 100.0
    );

    navigatorService.setInitialPolyPointsAndMarkers(0);
    navigatorService.setCurrentPolyline();
    navigatorService.findStepEndPoint();
    navigatorService.navigate(currentPosition);
    String direction = navigatorService.getDirection();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep()]["html_instructions"]);
  });

  test("getNextDirection Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    String direction = navigatorService.getNextDirection();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep() + 1]["html_instructions"]);
  });

  test("getArrivalTime Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    int direction = navigatorService.getArrivalTime();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep()]["duration"]);
  });

  test("getDistance Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    int direction = navigatorService.getDistance();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["steps"][navigatorService.getStep()]["distance"]);
  });

  test("getDeliveryArrivalTime Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    int direction = NavigationService.getDeliveryArrivalTime();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["duration"]);
  });

  test("getDeliveryDistance Test",() async {
    if(navigatorService == null){
      navigatorService = NavigationService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    int direction = navigatorService.getDeliveryDistance();
    expect(direction, json["routes"][navigatorService.getDelivery()]["legs"][navigatorService.getLeg()]["distance"]);
  });

  test("See if polylines and markers are made correctly", () async {
    if(navigatorService == null){
      navigatorService = NavigatorService(jsonFile: filename);
      await navigatorService.getRoutes();
    }

    navigatorService.setInitialPolyPointsAndMarkers(navigatorService.getDelivery());

    DeliveryRoute routes = navigatorService.getDeliveryRoute();
    int delivery = navigatorService.getDelivery();
    bool markersCorrect;
    bool polysCorrect;
    int numPolys = 0;

    for(int leg = 0; leg < routes.routes[delivery].legs.length; leg++){
      numPolys += 1;
    }

    if(navigatorService.markers.length == routes.routes[delivery].legs.length){
      markersCorrect = true;
    }
    else{
      markersCorrect = false;
    }

    if(navigatorService.polylines.length == numPolys){
      polysCorrect = true;
    }
    else{
      polysCorrect = false;
    }

    expect((markersCorrect && polysCorrect), true);
  });

  test("Get Polyline test", () async {
    if(navigatorService == null){
      navigatorService = NavigatorService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    bool created;
    String id = "0-0";
    navigatorService.setInitialPolyPointsAndMarkers(0);
    Polyline poly = navigatorService.getPolyline(id);

    if(poly is Polyline){
      created  = true;
    }
    else{
      created = false;
    }
    expect(created, true);
  });

  test("findStepStartPoint test should return true", () async {
    if(navigatorService == null){
      navigatorService = NavigatorService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    navigatorService.setInitialPolyPointsAndMarkers(0);
    navigatorService.setCurrentPolyline();
    navigatorService.findStepStartPoint();
    bool found = false;

    if(navigatorService.getStepStartPoint() is int){
      found = true;
    }

    expect(found, true);
  });

  test("findStepEndPoint test should return true", () async {
    if(navigatorService == null){
      navigatorService = NavigatorService(jsonFile: filename);
      await navigatorService.getRoutes();
    }
    navigatorService.setInitialPolyPointsAndMarkers(0);
    navigatorService.setCurrentPolyline();
    navigatorService.findStepEndPoint();
    bool found = false;

    if(navigatorService.getStepEndPoint() is int){
      found = true;
    }

    expect(found, true);
  });

  test("Some tests",() async {
    if(navigatorService == null){
      navigatorService = NavigatorService(jsonFile: filename);
      await navigatorService.getRoutes();
    }

    navigatorService.setInitialPolyPointsAndMarkers(0);
    navigatorService.setCurrentPolyline();
    navigatorService.setCurrentPoint(4);
    navigatorService.updateCurrentPolyline();

    expect(true, true);
  });





}