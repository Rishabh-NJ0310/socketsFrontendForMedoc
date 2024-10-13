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
  TextEditingController hospitalIdController = TextEditingController();
  TextEditingController nameController = TextEditingController();
  String hospitalId = '';
  String name = '';

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
    });
  }

  void joinHospitalRoom() {
    if (hospitalId.isNotEmpty && name.isNotEmpty) {
      socket.emit('join', {'hospitalId': hospitalId, 'clientType': 'ambulance', 'name': name});
      setState(() {
        status = 'Joined hospital room: $hospitalId as $name';
      });
    } else {
      setState(() {
        status = 'Please enter both hospital ID and name';
      });
    }
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
    if (hospitalId.isNotEmpty && name.isNotEmpty) {
      socket.emit('location', {
        'latitude': latitude,
        'longitude': longitude,
        'timestamp': DateTime.now().toIso8601String(),
        'hospitalId': hospitalId,
        'name': name,
      });
    } else {
      setState(() {
        status = 'Please enter both hospital ID and name';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Ambulance Location Sender'),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: hospitalIdController,
                decoration: InputDecoration(
                  labelText: 'Enter Hospital ID',
                ),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Enter Your Name',
                ),
              ),
              SizedBox(height: 20),
              ElevatedButton(
                onPressed: () {
                  setState(() {
                    hospitalId = hospitalIdController.text;
                    name = nameController.text;
                  });
                  joinHospitalRoom();
                },
                child: Text('Submit'),
              ),
              SizedBox(height: 20),
              Text(status),
            ],
          ),
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
