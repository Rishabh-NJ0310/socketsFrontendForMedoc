import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:geolocator/geolocator.dart';

void main() {
  runApp(MyApp());
}

void webMain() {
  main();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Ambulance Location Sender',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LocationSender(),
    );
  }
}

class LocationSender extends StatefulWidget {
  @override
  _LocationSenderState createState() => _LocationSenderState();
}

class _LocationSenderState extends State<LocationSender> {
  late IO.Socket socket;
  String status = 'Initializing...';
  String hospitalId =
      'hos_1A3D31'; // You should set this based on the user's hospital

  @override
  void initState() {
    super.initState();
    connectToSocket();
    startLocationUpdates();
  }

  void connectToSocket() {
    socket = IO.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });
    socket.connect();
    socket.onConnect((_) {
      setState(() {
        status = 'Connected to server';
      });
      print('Connected to socket server');
      joinHospitalRoom();
    });
  }

  void joinHospitalRoom() {
    socket.emit('join', {'hospitalId': hospitalId, 'clientType': 'ambulance'});
    setState(() {
      status = 'Joined hospital room: $hospitalId';
    });
  }

  void startLocationUpdates() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      setState(() {
        status = 'Location services are disabled';
      });
      return;
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        setState(() {
          status = 'Location permissions are denied';
        });
        return;
      }
    }

    if (permission == LocationPermission.deniedForever) {
      setState(() {
        status = 'Location permissions are permanently denied';
      });
      return;
    }

    Geolocator.getPositionStream().listen((Position position) {
      sendLocation(position.latitude, position.longitude);
      setState(() {
        status = 'Sent: ${position.latitude}, ${position.longitude}';
      });
    });
  }

  void sendLocation(double latitude, double longitude) {
    socket.emit('location', {
      'latitude': latitude,
      'longitude': longitude,
      'timestamp': DateTime.now().toIso8601String(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ambulance Location Sender'),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Hospital ID: $hospitalId'),
            SizedBox(height: 20),
            Text(status),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    super.dispose();
  }
}
