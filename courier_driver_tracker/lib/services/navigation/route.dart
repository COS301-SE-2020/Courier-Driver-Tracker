import 'package:courier_driver_tracker/services/navigation/bounds.dart';
import 'package:courier_driver_tracker/services/navigation/leg.dart';
import 'package:courier_driver_tracker/services/navigation/overview_polyline.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:json_annotation/json_annotation.dart';

part 'route.g.dart';

@JsonSerializable(explicitToJson: true)
class Route{
  Bounds bounds;
  List<Leg> legs;
  OverviewPolyline overviewPolyline;

  Route({this.overviewPolyline, this.bounds, this.legs});
  factory Route.fromJson(Map<String, dynamic> data) => _$RouteFromJson(data);
  Map<String, dynamic> toJson() => _$RouteToJson(this);
  String getHTMLInstruction(int leg, int step){
    return legs[leg].getHTMLInstruction(step);
  }

  String getManeuver(int leg, int step){
    return legs[leg].getManeuver(step);
  }

  int getDuration(int leg, int step){
    return legs[leg].getStepDuration(step);
  }

  int getDistance(int leg, int step){
    return legs[leg].getStepDistance(step);
  }

  int getDeliveryDuration(int leg){
    return legs[leg].getDeliveryDuration();
  }

  int getDeliveryDistance(int leg){
    return legs[leg].getDeliveryDistance();
  }

  int getRouteDistance(){
    int totalDist = 0;
    for(var leg in legs){
      totalDist += leg.distance;
    }
    return totalDist;
  }

  int getRouteDuration(){
    int totalDuration = 0;
    for(var leg in legs){
      totalDuration += leg.duration;
    }
    return totalDuration;
  }

  String getDeliveryAddress(int leg){
    return legs[leg].getDeliveryAddress();
  }

  LatLng getStepStartLatLng(int leg, int step){
    return legs[leg].getStepStartLatLng(step);
  }

  LatLng getStepEndLatLng(int leg, int step){
    return legs[leg].getStepEndLatLng(step);
  }

  LatLng getNorthEastBound(){
    return bounds.northEast;
  }

  LatLng getSouthWestBound(){
    return bounds.southWest;
  }

  LatLng getNextDeliveryLocation(int leg){
    return legs[leg].endLocation;
  }
}