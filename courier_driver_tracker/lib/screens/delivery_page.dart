import 'dart:convert';
import 'package:courier_driver_tracker/services/file_handling/route_logging.dart';
import 'package:courier_driver_tracker/services/api_handler/uncalculated_route_model.dart'
    as delivery;
import 'package:courier_driver_tracker/services/api_handler/api.dart';
import 'package:courier_driver_tracker/services/navigation/delivery_route.dart';
import 'package:courier_driver_tracker/services/navigation/navigation_service.dart';
import 'package:courier_driver_tracker/services/notification/local_notifications.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import "dart:ui";
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'dart:math';

class DeliveryPage extends StatefulWidget {
  @override
  _DeliveryPageState createState() => _DeliveryPageState();
}

class _DeliveryPageState extends State<DeliveryPage> {
  int _totalDistance = 0;
  int _totalDuration = 0;
  String _durationString;
  String _distanceString;
  String currentRoute = "-1";
  String _selectedRoute = "LOADING...";
  List pictures = [
    "assets/images/delivery-Icon-1.png",
    "assets/images/delivery-Icon-2.png",
    "assets/images/delivery-Icon-3.png",
    "assets/images/delivery-Icon-4.png",
    "assets/images/delivery-Icon-5.png"
  ];

  List random = [];

  List<Widget> _deliveries = [];
  List<Widget> _loadingDeliveries = [];

  ApiHandler _api = ApiHandler();
  FlutterSecureStorage storage = FlutterSecureStorage();

  double width;
  double height;

  @override
  void initState() {
    super.initState();
    getRoutesFromAPI();
    getOrder();
  }

  int getRandomPic() {
    var now = new DateTime.now();
    Random rnd2 = new Random(now.millisecondsSinceEpoch);
    int min = 0, max = 5;
    int r = min + rnd2.nextInt(max - min);
    return r;
  }

  void getOrder() {
    List used = [];

    while (used.length < 5) {
      int num = getRandomPic();
      bool status = true;
      for (int j = 0; j < used.length; j++) {
        if (used[j] == num) {
          status = false;
        }
      }
      if (status == true) {
        used.add(num);
      }
    }
    this.random = used;
  }

  String getPicPath() {
    int num1 = this.random[0];
    this.random.removeAt(0);
    return this.pictures[num1];
  }

  String getTag() {
    int num1 = this.random[0];
    return this.pictures[num1];
  }

  String getCurrentRoute() {
    if (this.currentRoute == null || this.currentRoute == '-1') {
      return "Current Route: none";
    } else {
      int routeNum = int.parse(this.currentRoute) + 1;
      return "Current Route: $routeNum";
    }
  }

  getRoutesFromAPI() async {
    // see if driver has routes still stored
    NavigationService navigationService = NavigationService();
    if(navigationService.isRouteInitialised()){
      await getRoutesFromNavigation();
      return;
    }
    _totalDuration = 0;
    _totalDistance = 0;

    List<delivery.Route> routes = await _api.getUncalculatedRoute();
    String currentRoute = await storage.read(key: 'current_route');
    this.currentRoute = currentRoute;

    int currentActiveRoute;
    if (currentRoute == null) {
      currentActiveRoute = -1;
    } else {
      _selectedRoute = currentRoute;
      currentActiveRoute = int.parse(currentRoute);
    }

    if (routes != null && currentActiveRoute == -1) {
      // notify abnormality about not completing a route
      print("You have an unfinished route!!");

    }

    // if not initialise his routes
    await _api.initDriverRoute();
    routes = await _api.getUncalculatedRoute();

    // check to see if he has no routes
    if (routes == null) {
      //write deliveries to file
      if (this.mounted) {
        setState(() {
          _durationString = "N/A";
          _loadingDeliveries.add(Padding(
            padding: const EdgeInsets.all(2.0),
            child: _buildNoRoute("assets/images/delivery-Icon-6.png",
                "No Routes Available", "", "You have no routes.", "", -1),
          ));

          _deliveries = _loadingDeliveries;
        });
        print("Dev: Error while retrieving uncalculated routes");
      }
      return;
    }

    // he has routes
    // remove all unnecessary information from json object
    Map<String, dynamic> deliveryRoutes = {"routes": []};
    for (int i = 0; i < routes.length; i++) {
      await _api.initCalculatedRoute(routes[i].routeID);
      var activeRoute = await _api.getActiveCalculatedRoute();

      if (activeRoute == null) {
        setState(() {
          _durationString = "N/A";
          _loadingDeliveries.add(Padding(
            padding: const EdgeInsets.all(2.0),
            child: _buildNoRoute("assets/images/delivery-Icon-6.png",
                "No Routes Available", "", "Could not load route.", "", -1),
          ));

          _deliveries = _loadingDeliveries;
        });

        print("Dev: error while retrieving active calculated route locally.");
        return;
      }

      // create every route
      for (var route in activeRoute['routes']) {
        // temp route
        Map<String, dynamic> deliveryRoute = {"legs": []};
        // setting bounds
        deliveryRoute["bounds"] = {
          "northeast": {
            "lat": route["bounds"]["northeast"]["lat"],
            "lng": route["bounds"]["northeast"]["lng"]
          },
          "southwest": {
            "lat": route["bounds"]["southwest"]["lat"],
            "lng": route["bounds"]["southwest"]["lng"]
          }
        };
        // setting overview polyline
        deliveryRoute["overview_polyline"] = {
          "points": route["overview_polyline"]["points"]
        };

        int distance = 0;
        int duration = 0;
        int numDeliveries;

        int j = 0;
        // creating legs for each route
        for (var leg in route['legs']) {
          // temp leg
          Map<String, dynamic> deliveryLeg = {"steps": []};

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
          for (var step in leg['steps']) {
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

        _loadingDeliveries.add(Padding(
          padding: const EdgeInsets.all(2.0),
          child: _buildRoute(
              "assets/images/delivery-Icon-1.png",
              "Route $routeNum",
              "Distance: " + getDeliveryDistanceString(distance),
              "Time: " + getTimeString(duration),
              "Deliveries: $numDeliveries",
              i),
        ));
      }
      if (storage.read(key: 'route$i') == null) {
        storage.write(key: 'route$i', value: '0-0');
      }
    }

    //write deliveries to file
    RouteLogging logger = RouteLogging();
    logger.writeToFile(jsonEncode(deliveryRoutes), "deliveriesFile");
    storage.write(key: 'route_initialised', value: 'true');
    // set info variables
    setState(() {
      _durationString = getTimeString(_totalDuration);
      _distanceString = getDeliveryDistanceString(_totalDistance);
      print("Dist: $_distanceString");
      print("Dur: $_durationString");
      _deliveries = _loadingDeliveries;
    });
  }

  getRoutesFromNavigation() async {
    NavigationService navigationService = NavigationService();
    this.currentRoute = await storage.read(key: 'current_route');
    if (!navigationService.isRouteInitialised()) {
      await navigationService.initialiseRoutes();
    }

    DeliveryRoute deliveries = navigationService.getDeliveryRoutes();

    if (deliveries == null && this.mounted) {
      setState(() {
        _durationString = "";
        _loadingDeliveries.add(Padding(
          padding: const EdgeInsets.all(2.0),
          child: _buildNoRoute(
              "assets/images/delivery-Icon-1.png",
              "Failed to load Routes",
              "",
              "Could not load route. Contact your manager for assistance.",
              "",
              -1),
        ));

        _deliveries = _loadingDeliveries;
      });

      print("Dev: error while retrieving active calculated route locally.");
      return;
    }

    int del = 1;
    int totalDuration = 0;
    int totalDistance = 0;
    for (var route in deliveries.routes) {
      int distance = navigationService.getRouteDistance(del - 1);
      totalDistance += distance;
      int duration = navigationService.getRouteDuration(del - 1);
      totalDuration += duration;
      int numDeliveries = navigationService.getTotalDeliveries();

      _loadingDeliveries.add(Padding(
        padding: const EdgeInsets.all(2.0),
        child: _buildRoute(
            "assets/images/delivery-Icon-1.png",
            "Route $del",
            "Distance: " + getDeliveryDistanceString(distance),
            "Time: " + getTimeString(duration),
            "Deliveries: $numDeliveries",
            del - 1),
      ));
    }
    if (this.mounted) {
      setState(() {
        _distanceString = getDeliveryDistanceString(totalDistance);
        _durationString = getTimeString(totalDuration);
        _deliveries = _loadingDeliveries;
      });
    }
  }

  String getTimeString(int time) {
    int hours = 0;
    int minutes = (time / 60).round();

    while (minutes > 60) {
      hours += 1;
      minutes -= 60;
    }

    if (hours == 0) {
      return "$minutes min";
    } else {
      return "$hours h $minutes min";
    }
  }

  String getDeliveryDistanceString(int dist) {
    int distance = dist;

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

  drivingWithNoRoutes() async {
    await Future.delayed(Duration(minutes: 2));
    LocalNotifications notificationManager = LocalNotifications();
    notificationManager.showNotifications(
        "You are driving outside company hours!",
        "You are using the application for personal use.");
  }

  void checkCurrentRoute(BuildContext context, int route) async {
    if (this.currentRoute == null ||
        this.currentRoute == "-1" ||
        this.currentRoute == route.toString()) {
      await storage.write(key: 'current_route', value: '$route');
      Navigator.of(context).pop();
    } else {
      showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              title: Text("You already have a route in progress"),
              content: Text("Please complete your current route."),
              actions: <Widget>[
                FlatButton(
                  child: Text('Cancel'),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
              ],
            );
          });
    }
  }

  @override
  Widget build(BuildContext context) {
    width = MediaQuery.of(context).size.width;
    height = MediaQuery.of(context).size.height;
    return Scaffold(
        bottomNavigationBar: Container(
            decoration: BoxDecoration(
              color: Colors.white,
            ),
            child: _buildBottomNavigationBar),
        backgroundColor: Colors.blue[600],
        body: Container(
          child: Column(
            children: <Widget>[
              SizedBox(height: 25.0),
              Padding(
                padding: EdgeInsets.only(left: 40.0),
                child: Column(children: <Widget>[
                  Row(
                    children: <Widget>[
                      Text('Active',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: height * 0.04)),
                      SizedBox(width: 10.0),
                      Text('Routes',
                          style: TextStyle(
                              fontFamily: 'Montserrat',
                              color: Colors.white,
                              fontSize: height * 0.03))
                    ],
                  ),
                  SizedBox(height: 10.0),
                  Row(
                    children: <Widget>[
                      RichText(
                          text: TextSpan(children: [
                        WidgetSpan(
                          child: Icon(FontAwesomeIcons.road,
                              color: Colors.grey[100]),
                        ),
                        TextSpan(
                            text: "  Total KM : $_distanceString\n",
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                                fontSize: height * 0.025)),
                        WidgetSpan(
                          child: Icon(FontAwesomeIcons.clock,
                              color: Colors.grey[100]),
                        ),
                        TextSpan(
                            text: "  Total time : $_durationString\n\n",
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                                fontSize: height * 0.025)),
                        TextSpan(
                            text: getCurrentRoute(),
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                color: Colors.white,
                                fontSize: height * 0.02))
                      ]))
                    ],
                  ),
                ]),
              ),
              SizedBox(height: 20),
              Expanded(
                child: Container(
                  height: height * 0.6,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius:
                        BorderRadius.only(topLeft: Radius.circular(75.0)),
                  ),
                  child: Stack(
                    children: <Widget>[
                      Padding(
                          padding: EdgeInsets.only(top: 45.0),
                          child: ListView(children: _deliveries)),
                      Padding(
                        padding:
                            const EdgeInsets.only(right: 20.0, bottom: 20.0),
                        child: Align(
                          alignment: Alignment.bottomRight,
                          child: FloatingActionButton(
                            onPressed: getRoutesFromAPI,
                            tooltip: 'refresh',
                            child: new Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ));
  }

  Widget _buildRoute(String imagePath, String routeNum, String distance,
      String time, String del, int route) {
    return Padding(
        padding:
            EdgeInsets.only(left: width * 0.1, right: width * 0.1, top: 10.0),
        child: InkWell(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                    child: Row(children: [
                  Hero(
                      tag: getTag(),
                      child: Image(
                          image: AssetImage(getPicPath()),
                          fit: BoxFit.cover,
                          height: width * 0.30,
                          width: width * 0.30)),
                  SizedBox(width: 10.0),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routeNum,
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: height * 0.035,
                                fontWeight: FontWeight.bold)),
                        Text("$distance\n$time\n$del",
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: height * 0.02,
                                color: Colors.grey)),
                      ])
                ])),
                IconButton(
                    icon: Icon(Icons.add),
                    color: Colors.black,
                    onPressed: () => checkCurrentRoute(context, route))
              ],
            )));
  }

  Widget _buildNoRoute(String imagePath, String routeNum, String distance,
      String time, String del, int route) {
    return Padding(
        padding: EdgeInsets.only(
          left: width * 0.04,
          right: width * 0.1,
        ),
        child: InkWell(
            onTap: () {},
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: <Widget>[
                Container(
                    child: Row(children: [
                  Hero(
                      tag: getTag(),
                      child: Image(
                          image:
                              AssetImage("assets/images/delivery-Icon-6.png"),
                          fit: BoxFit.cover,
                          height: width * 0.3,
                          width: width * 0.3)),
                  SizedBox(width: 10.0),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(routeNum,
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: height * 0.028,
                                fontWeight: FontWeight.bold)),
                        Text("$distance\n$time\n$del",
                            style: TextStyle(
                                fontFamily: 'Montserrat',
                                fontSize: height * 0.02,
                                color: Colors.grey)),
                      ])
                ])),
              ],
            )));
  }

  Widget get _buildBottomNavigationBar {
    return ClipRRect(
        borderRadius: BorderRadius.only(
          topRight: Radius.circular(30),
          topLeft: Radius.circular(30),
        ),
        child: BottomNavigationBar(
            backgroundColor: Colors.black87,
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
