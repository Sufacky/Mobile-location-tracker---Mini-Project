import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';
import 'package:flutter/material.dart';
import 'package:google_map_live/mymap.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(MaterialApp(home: MyApp()));
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final loc.Location location = loc.Location();
  StreamSubscription<loc.LocationData>? _locationSubscription;
  var id = 0;

  @override
  void initState() {
    super.initState();
    _requestPermission();
    location.changeSettings(interval: 300, accuracy: loc.LocationAccuracy.high);
    location.enableBackgroundMode(enable: true);
  }

  Future<void> _getLocation() async {
    // get location and add it to firebase
    try {
      final loc.LocationData _locationResult =
          await location.getLocation(); // get location
      setState(() {
        id++;
      });

      var doc = FirebaseFirestore.instance
          .collection('location')
          .doc('user$id'); // create firebase document
      doc // add fields to document
          .set({
        'uniqueID': 'user$id',
        'latitude': _locationResult.latitude,
        'longitude': _locationResult.longitude,
        'time': DateFormat('EEE d MMM kk:mm:ss').format(DateTime.now()),
        'address': await _getAddress(
            _locationResult.latitude!, _locationResult.longitude!)
      }, SetOptions(merge: true));
    } catch (e) {
      print(e);
    }
  }

  Future<void> _listenLocation() async {
    _locationSubscription = location.onLocationChanged.handleError((onError) {
      print(onError);
      _locationSubscription?.cancel();
      setState(() {
        _locationSubscription = null;
      });
    }).listen((loc.LocationData currentlocation) async {
      var doc = FirebaseFirestore.instance
          .collection('location')
          .doc('user$id'); // create firebase document
      doc // add fields to document
          .update({
        'uniqueID': 'user$id',
        'latitude': currentlocation.latitude,
        'longitude': currentlocation.longitude,
        'time': DateFormat('EEE d MMM kk:mm:ss').format(DateTime.now()),
        'address': await _getAddress(
            currentlocation.latitude!, currentlocation.longitude!)
      });
    });
  }

  Future<String> _getAddress(double latitude, double longitude) async {
    List<Placemark> placemarks =
        await placemarkFromCoordinates(latitude, longitude);
    Placemark place = placemarks[0];

    return '${place.street} ${place.subLocality}, ${place.locality}, ${place.country}';
  }

  _stopListening() {
    _locationSubscription?.cancel();
    setState(() {
      _locationSubscription = null;
    });
  }

  _requestPermission() async {
    // asking for user permission to use location
    var status = await Permission.location.request();
    if (status.isGranted) {
      print('done');
    } else if (status.isDenied) {
      _requestPermission();
    } else if (status.isPermanentlyDenied) {
      openAppSettings();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Image.asset(
            'assets/images/live_loc image.jpg',
            width: 20,
            height: 20,
          ),
        ),
        title: Text('Live Location Tracker'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Container(
        margin: EdgeInsets.only(top: 20.0),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                Column(
                  children: [
                    Image.asset(
                      'assets/images/map-marker-plus.png',
                      color: Colors.green,
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          await _getLocation();
                        },
                        child: Text('Add My Location')),
                  ],
                ),
                Column(
                  children: [
                    Image.asset(
                      'assets/images/map-marker-radius.png',
                      color: Colors.amberAccent,
                    ),
                    ElevatedButton(
                        onPressed: () async {
                          await _listenLocation();
                        },
                        child: Text('Enable Live Location')),
                  ],
                ),
              ],
            ),
            SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Column(
                  children: [
                    Image.asset(
                      'assets/images/map-marker-off.png',
                      color: Colors.red,
                    ),
                    ElevatedButton(
                        onPressed: () {
                          _stopListening();
                        },
                        child: Text('Stop Live Location')),
                  ],
                ),
              ],
            ),
            Expanded(
                child: StreamBuilder(
              stream:
                  FirebaseFirestore.instance.collection('location').snapshots(),
              builder: (context, AsyncSnapshot<QuerySnapshot> snapshot) {
                if (!snapshot.hasData) {
                  // if no data show progress bar
                  return Center(child: CircularProgressIndicator());
                }
                return ListView.builder(
                    itemCount: snapshot.data?.docs.length,
                    itemBuilder: (context, index) {
                      return Card(
                        color: Colors.blue.shade200,
                        margin: EdgeInsets.only(bottom: 2),
                        child: ListTile(
                          title: Row(
                            children: [
                              Text(
                                snapshot.data!.docs[index]['time'].toString(),
                              ),
                              Container(
                                margin: EdgeInsets.only(left: 25),
                                child: IconButton(
                                    onPressed: () {
                                      var doc = FirebaseFirestore.instance
                                          .collection('location')
                                          .doc(snapshot
                                              .data!.docs[index]['uniqueID']
                                              .toString());
                                      doc.delete();
                                    },
                                    icon: Icon(
                                      Icons.delete,
                                      color: Colors.red,
                                    )),
                              )
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  snapshot.data!.docs[index]['address']
                                      .toString(),
                                  overflow: TextOverflow.ellipsis,
                                  maxLines: 4,
                                ),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            color: Colors.green,
                            icon: Icon(Icons.directions),
                            onPressed: () {
                              Navigator.of(context).push(MaterialPageRoute(
                                  builder: (context) =>
                                      MyMap(snapshot.data!.docs[index].id)));
                            },
                          ),
                          isThreeLine: true,
                        ),
                      );
                    });
              },
            )),
          ],
        ),
      ),
    );
  }
}
