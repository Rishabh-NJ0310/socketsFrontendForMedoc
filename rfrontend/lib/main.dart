import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Hospital Ambulance Tracker',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: LocationReceiver(),
    );
  }
}

class LocationReceiver extends StatefulWidget {
  @override
  _LocationReceiverState createState() => _LocationReceiverState();
}

class _LocationReceiverState extends State<LocationReceiver> {
  late IO.Socket socket;
  String connectionStatus = 'Disconnected';
  List<String> logs = [];
  Map<String, Map<String, dynamic>> ambulanceLocations = {};
  String hospitalId = 'hos_1A3D31'; // Set this based on the hospital's ID

  @override
  void initState() {
    super.initState();
    connectToSocket();
  }

  void connectToSocket() {
    addLog('Attempting to connect to socket...');
    socket = IO.io('http://localhost:5000', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
    });

    socket.connect();

    socket.onConnect((_) {
      addLog('Connected to socket server');
      setState(() {
        connectionStatus = 'Connected';
      });
      joinHospitalRoom();
    });

    // Listening for location updates from ambulances
    socket.on('locationUpdate', (data) {
      addLog('Received location update: $data');
      setState(() {
        ambulanceLocations[data['name']] = {
          'ambulanceId': data['ambulanceId'], // Storing the ambulance ID
          'latitude': data['latitude'],
          'longitude': data['longitude'],
          'timestamp': data['timestamp'],
        };
      });
    });

    socket.onDisconnect((_) {
      addLog('Disconnected from socket server');
      setState(() {
        connectionStatus = 'Disconnected';
      });
    });

    socket.onError((error) {
      addLog('Socket error: $error');
    });
  }

  void joinHospitalRoom() {
    socket.emit('join', {'hospitalId': hospitalId, 'clientType': 'hospital'});
    addLog('Joined hospital room: $hospitalId');
  }

  void addLog(String message) {
    setState(() {
      logs.add('${DateTime.now()}: $message');
      if (logs.length > 100) logs.removeAt(0); // Limit log size
    });
    print(message); // Also print to console for debugging
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hospital Ambulance Tracker'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Hospital ID: $hospitalId'),
            Text('Connection Status: $connectionStatus'),
            SizedBox(height: 20),
            Text('Ambulance Locations:'),
            Expanded(
              child: ListView.builder(
                itemCount: ambulanceLocations.length,
                itemBuilder: (context, index) {
                  String ambulanceName =
                      ambulanceLocations.keys.elementAt(index);
                  var location = ambulanceLocations[ambulanceName]!;
                  return ListTile(
                    title: Text(
                        'Ambulance Name: $ambulanceName (ID: ${location['ambulanceId']})'),
                    subtitle: Text(
                      'Lat: ${location['latitude']}, Lon: ${location['longitude']}\n'
                      'Last Update: ${location['timestamp']}',
                    ),
                  );
                },
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                socket.disconnect();
                connectToSocket();
              },
              child: Text('Reconnect Socket'),
            ),
            SizedBox(height: 20),
            Text('Debug Logs:'),
            Expanded(
              child: ListView.builder(
                itemCount: logs.length,
                itemBuilder: (context, index) {
                  return Text(logs[logs.length - 1 - index]);
                },
              ),
            ),
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
