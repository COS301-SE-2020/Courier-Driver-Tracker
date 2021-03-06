import 'dart:convert';
import 'package:courier_driver_tracker/services/file_handling/route_logging.dart';
import 'package:courier_driver_tracker/services/api_handler/uncalculated_route_model.dart' as delivery;
import 'package:courier_driver_tracker/services/api_handler/api.dart';
import 'package:courier_driver_tracker/services/navigation/delivery_route.dart';
import 'package:courier_driver_tracker/services/navigation/navigation_service.dart';
import 'package:courier_driver_tracker/services/notification/local_notifications.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import "dart:ui";
import 'package:font_awesome_flutter/font_awesome_flutter.dart';

class DeliveryScreen extends StatefulWidget {
  @override
  _DeliveryScreenState createState() => _DeliveryScreenState();
}

class _DeliveryScreenState extends State<DeliveryScreen> {
  final headingLabelStyle = TextStyle(
      fontSize: 25, fontFamily: 'OpenSans-Regular', color: Colors.grey[300]);
  final headingLabelStyle2 = TextStyle(
      fontSize: 30, fontFamily: 'OpenSans-Regular', color: Colors.grey[100]);
  final textStyle = TextStyle(
      fontSize: 20, fontFamily: 'OpenSans-Regular', color: Colors.grey[100]);

  int _totalDistance = 0;
  int _totalDuration = 0;
  String _durationString;
  String _selectedRoute = "LOADING...";

  List<Widget> _deliveries = [];
  List<Widget> _loadingDeliveries = [];

  ApiHandler _api = ApiHandler();
  FlutterSecureStorage storage = FlutterSecureStorage();

  @override
  void initState() {
    NavigationService navigationService = NavigationService();
    if(!navigationService.isRouteInitialised()){
      getRoutesFromAPI();
    }
    else{
      getRoutesFromNavigation();
    }

    super.initState();
  }

  getRoutesFromAPI() async{
    // see if driver has routes still stored
    List<delivery.Route> routes = await _api.getUncalculatedRoute();
    String currentRoute = await storage.read(key: 'current_route');

    int currentActiveRoute;
    if(currentRoute == null){
      currentActiveRoute = -1;
    }
    else{
      _selectedRoute = currentRoute;
      currentActiveRoute = int.parse(currentRoute);
    }

    if(routes != null && currentActiveRoute == -1){
      // notify abnormality about not completing a route
      print("You have an unfinished route!!");
    }

    // if not initialise his routes
    await _api.initDriverRoute();
    routes = await _api.getUncalculatedRoute();

    // check to see if he has no routes
    if(routes == null){
      //write deliveries to file


      if(this.mounted){
        setState(() {
          _durationString = "";
          _loadingDeliveries.add(Padding(
            padding: const EdgeInsets.all(2.0),
            child: _deliveryCards("No Routes Available", "",
                "You have no routes for the day. Ensure to exit app completely." , "", -1),
          ));

          _deliveries = _loadingDeliveries;
        });
        print("Dev: Error while retrieving uncalculated routes");
      }
      return;
    }

    // he has routes
    // remove all unnecessary information from json object
    Map<String, dynamic> deliveryRoutes = {
      "routes" : []
    };
    for(int i = 0; i < routes.length; i++){
      await _api.initCalculatedRoute(routes[i].routeID);
      var activeRoute = await _api.getActiveCalculatedRoute();

      if(activeRoute == null){
        setState(() {
          _durationString = "";
          _loadingDeliveries.add(Padding(
            padding: const EdgeInsets.all(2.0),
            child: _deliveryCards("No Routes Available", "",
                "Could not load route. Contact your manager for assistance." , "", -1),
          ));

          _deliveries = _loadingDeliveries;
        });

        print("Dev: error while retrieving active calculated route locally.");
        return;
      }

      // create every route
      for(var route in activeRoute['routes']){

        // temp route
        Map<String, dynamic> deliveryRoute = {
          "legs" : []
        };
        // setting bounds
        deliveryRoute["bounds"] = {
          "northeast" : {
            "lat" : route["bounds"]["northeast"]["lat"],
            "lng" : route["bounds"]["northeast"]["lng"]
          },
          "southwest" : {
            "lat" : route["bounds"]["southwest"]["lat"],
            "lng" : route["bounds"]["southwest"]["lng"]
          }
        };
        // setting overview polyline
        deliveryRoute["overview_polyline"] = {
          "points" :  route["overview_polyline"]["points"]
        };

        int distance = 0;
        int duration = 0;
        int numDeliveries;

        int j = 0;
        // creating legs for each route
        for(var leg in route['legs']){

          // temp leg
          Map<String, dynamic> deliveryLeg = {
            "steps" : []
          };


          // setting leg information variables
          deliveryLeg["distance"] = leg["distance"]["value"];
          distance += leg["distance"]["value"];
          _totalDistance += leg["distance"]["value"];
          deliveryLeg["duration"] = leg["duration"]["value"];
          duration += leg["duration"]["value"];
          _totalDuration += leg["duration"]["value"];
          deliveryLeg["end_address"] = leg["end_address"];
          deliveryLeg["end_location"] = leg["end_location"];
          deliveryLeg["start_address"] = leg["start_address"];
          deliveryLeg["start_location"] = leg["start_location"];

          // creating steps for each leg
          for(var step in leg['steps']){
            // temp step
            Map<String, dynamic> deliveryStep = {};

            // setting step information
            deliveryStep["distance"] = step["distance"]["value"];
            deliveryStep["duration"] = step["duration"]["value"];
            deliveryStep["end_location"] = step["end_location"];
            deliveryStep["start_location"] = step["start_location"];
            deliveryStep["html_instructions"] = step["html_instructions"];
            deliveryStep["polyline"] = step["polyline"];
            deliveryStep["maneuver"] = step["maneuver"];

            // add step to leg steps
            deliveryLeg["steps"].add(deliveryStep);
          }
          // add leg to routes
          deliveryRoute["legs"].add(deliveryLeg);

          j++;
          numDeliveries = j - 1;
        }
        // add route to delivery routes
        deliveryRoutes["routes"].add(deliveryRoute);

        // create delivery cards
        int routeNum = i + 1;
        distance = (distance/1000).ceil();
        duration = (duration/60).ceil();
        _loadingDeliveries.add(Padding(
          padding: const EdgeInsets.all(2.0),
          child: _deliveryCards("Route $routeNum", "Distance: $distance Km",
              "Time: " + getTimeString(duration), "Deliveries: $numDeliveries", i),
        ));
      }
      if(storage.read(key: 'route$i') == null){
        storage.write(key: 'route$i', value: '0-0');
      }
    }


    //write deliveries to file
    RouteLogging logger = RouteLogging();
    logger.writeToFile(jsonEncode(deliveryRoutes), "deliveriesFile");
    storage.write(key: 'route_initialised', value: 'true');
    // set info variables
    setState(() {
      _totalDistance = (_totalDistance/1000).ceil();
      _totalDuration = (_totalDuration/60).ceil();

      _durationString = getTimeString(_totalDuration);
      _deliveries = _loadingDeliveries;
    });
  }

  getRoutesFromNavigation() async {
    NavigationService navigationService = NavigationService();
    print("Deliveries: " + navigationService.getTotalDeliveries().toString());

    if(!navigationService.isRouteInitialised()){
      await navigationService.initialiseRoutes();
    }

    DeliveryRoute deliveries = navigationService.getDeliveryRoutes();

    if(deliveries == null && this.mounted){
      setState(() {
        _durationString = "";
        _loadingDeliveries.add(Padding(
          padding: const EdgeInsets.all(2.0),
          child: _deliveryCards("Failed to load Routes", "",
              "Could not load route. Contact your manager for assistance." , "", -1),
        ));

        _deliveries = _loadingDeliveries;
      });

      print("Dev: error while retrieving active calculated route locally.");
      return;
    }



    for(var route in deliveries.routes) {
      // create delivery cards
    }
  }


  String getTimeString(int time){
    int hours = 0;
    int minutes = time;

    while(minutes > 60){
      hours += 1;
      minutes -= 60;
    }

    if(hours == 0){
      return "$minutes min";
    }
    else{
      return "$hours h $minutes min";
    }
  }



  drivingWithNoRoutes() async {
    await Future.delayed(Duration(minutes: 2));
    LocalNotifications notificationManager = LocalNotifications();
    notificationManager.showNotifications("You are driving outside company hours!", "You are using the application for personal use.");
  }

  Widget _deliveryCards(String text, String distance, String time, String del, int route) {
    return Card(
      color: Colors.grey[800],
      elevation: 10,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        child: Center(
          child: ListTile(
            leading: Padding(
              padding: const EdgeInsets.only(top: 16.0, right: 10.0),
              child: CircleAvatar(
                  backgroundColor: Colors.green,
                  radius: 25,
                  child: Icon(
                    FontAwesomeIcons.check,
                    color: Colors.grey[100],
                    size: 22,
                  )),
            ),
            title: Padding(
              padding: const EdgeInsets.only(bottom: 5.0),
              child: Text(
                text,
                style: headingLabelStyle,
              ),
            ),
            subtitle: Text(
              "$distance\n$time\n$del",
              style: textStyle,
            ),
            trailing: Padding(
              padding: const EdgeInsets.only(top: 18.0),
              child: IconButton(
                icon: Icon(
                  Icons.keyboard_arrow_right,
                  color: Colors.grey[100],
                  size: 30,
                ),
                  onPressed: () async{
                    await storage.write(key: 'current_route', value: '$route');
                    Navigator.of(context).pop();
                  },
              )
            ),
          ),
        ),
      ),
    );
  }

  BoxDecoration myBoxDecoration() {
    return BoxDecoration(
        borderRadius: BorderRadius.only(
            bottomRight: Radius.circular(15),
            bottomLeft: Radius.circular(15) //         <--- border radius here
            ),
        color: Colors.blue,
        boxShadow: [
          BoxShadow(
              color: Colors.grey[900],
              spreadRadius: 2,
              blurRadius: 5,
              offset: Offset(0, 3))
        ]);
  }

  BoxDecoration tickBoxDecoration() {
    return BoxDecoration(
      color: Colors.green,
    );
  }

  @override
  Widget build(BuildContext context) {
    return new Scaffold(
        bottomNavigationBar: _buildBottomNavigationBar,
        backgroundColor: Colors.grey[900],
        body: SafeArea(
            child: Column(children: <Widget>[
          Expanded(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 7.0),
              child: Container(
                decoration: myBoxDecoration(),
                child: ListTile(
                  title: Padding(
                    padding: const EdgeInsets.only(bottom: 3.0),
                    child: Text("Today's Routes", style: headingLabelStyle2),
                  ),
                  subtitle: RichText(
                      text: TextSpan(children: [
                    WidgetSpan(
                      child:
                          Icon(FontAwesomeIcons.road, color: Colors.grey[100]),
                    ),
                    TextSpan(text: "  Total KM : $_totalDistance Km\n", style: textStyle),
                    WidgetSpan(
                      child:
                          Icon(FontAwesomeIcons.clock, color: Colors.grey[100]),
                    ),
                    TextSpan(
                        text: "  Total time : $_durationString\n\n", style: textStyle),
                    TextSpan(
                        text: "Current Route: $_selectedRoute", style: textStyle)
                  ])),
                ),
              ),
            ),
          ),
          Expanded(
            flex: 6,
            child: ListView(
              padding: const EdgeInsets.all(5),
              children: _deliveries
            ),
          ),
        ])));
  }

  Widget get _buildBottomNavigationBar {
    return ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          topLeft: Radius.circular(30),
        ),
        child: BottomNavigationBar(
            backgroundColor: Colors.grey[800],
            unselectedItemColor: Colors.grey[100],
            type: BottomNavigationBarType.fixed,
            items: [
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.home, size: 30, color: Colors.blue),
                title: SizedBox(
                  width: 0,
                  height: 0,
                ),
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.mapMarkerAlt,
                    size: 30, color: Colors.grey[100]),
                title: SizedBox(
                  width: 0,
                  height: 0,
                ),
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.userAlt,
                    size: 30, color: Colors.grey[100]),
                title: SizedBox(
                  width: 0,
                  height: 0,
                ),
              ),
              BottomNavigationBarItem(
                icon: Icon(FontAwesomeIcons.cog,
                    size: 30, color: Colors.grey[100]),
                title: SizedBox(
                  width: 0,
                  height: 0,
                ),
              )
            ],
            onTap: (index) {
              if (index == 1) {
                Navigator.of(context).pop();
              } else if (index == 2) {
                Navigator.of(context).popAndPushNamed("/profile");
              } else if (index == 3) {
                Navigator.of(context).popAndPushNamed("/settings");
              }
            }));
  }
}
