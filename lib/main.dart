import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sensors/sensors.dart';
import 'package:flutter_compass/flutter_compass.dart';
import 'package:http/http.dart' as http;

void main() {
  runApp(MyApp());
}

class MyApp extends StatefulWidget {
  @override
  _MyAppState createState() => _MyAppState();
}

enum PedestrianStatus {
  stopped,
  walking,
}

enum PowerLevel {
  low,
  medium,
  high,
}

class _MyAppState extends State<MyApp> with SingleTickerProviderStateMixin {
  String _direction = '';
  PedestrianStatus _status = PedestrianStatus.stopped;
  PowerLevel _powerLevel = PowerLevel.medium;
  double _initialDirection = 0.0;
  double _currentDirection = 0.0;
  bool _connected = false;
  String _ipAddress = '';

  late AnimationController _animationController;
  late Animation<double> _powerLevelAnimation;

  @override
  void initState() {
    super.initState();
    _initAccelerometer();
    _initCompass();

    _animationController = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: 500),
    );

    _powerLevelAnimation = CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeInOut,
    );

    _animationController.forward();

    Timer.periodic(Duration(milliseconds: 100), (_) {
      _updateDirectionAndStatus();
      _initAccelerometer();
    });

  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  void _initAccelerometer() {
    accelerometerEvents.listen((AccelerometerEvent event) {
      setState(() {
        double acceleration = event.x * event.x + event.y * event.y + event.z * event.z;
        if (_status == PedestrianStatus.stopped && acceleration > 115.0) {
          _status = PedestrianStatus.walking;
          Timer(Duration(seconds: 2), () {
            _status = PedestrianStatus.stopped;
          });
        }
      });
    });
  }



  void _initCompass() {
    FlutterCompass.events?.listen((event) {
      setState(() {
        _currentDirection = event.heading ?? 0.0;
      });
    });
  }

  void _updateDirectionAndStatus() {
    setState(() {
      _direction = _calculateDirection();


    });
  }

  void _storeInitialDirection() {
    setState(() {
      _initialDirection = _currentDirection;
    });
  }

  void _startSendingData() {
    if (_ipAddress.isEmpty) {
      print('Please enter the IP address of the NodeMCU');
      return;
    }

    setState(() {
      _connected = true;
    });

    Timer.periodic(Duration(milliseconds: 100), (_) {
      _sendDataToNodeMCU();
    });

  }

  void _sendDataToNodeMCU() {
    if (!_connected) {
      print("Not connected to NodeMCU");
      return;
    }

    String power;
    switch (_powerLevel) {
      case PowerLevel.low:
        power = 'low';
        break;
      case PowerLevel.medium:
        power = 'medium';
        break;
      case PowerLevel.high:
        power = 'high';
        break;
      default:
        power = 'medium';
        break;
    }

    String url = 'http://$_ipAddress/?speed=${_status.toString().split('.').last}&direction=$_direction&power=$power';

    http.get(Uri.parse(url)).then((response) {
      print('Data sent to NodeMCU');
    }).catchError((error) {
      print('Error sending data: $error');
    });
  }

  String _calculateDirection() {
    double difference = _currentDirection - _initialDirection;
    if (difference > 70) {
      _initialDirection = _currentDirection;
      return 'right';
    } else if (difference < -70) {
      _initialDirection = _currentDirection;
      return 'left';
    } else {
      return 'forward';
    }
  }

  void _disconnectNodeMCU() {
    setState(() {
      _connected = false;
    });
  }

  String _getSpeed() {
    switch (_powerLevel) {
      case PowerLevel.low:
        return '1';
      case PowerLevel.medium:
        return '2';
      case PowerLevel.high:
        return '3';
      default:
        return '2';
    }
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Pedestrian Tracker'),
        ),
        body: Column(
          children: [
            Text('Direction: $_direction'),
            Text('Pedestrian Status: ${_status.toString().split('.').last}'),
            SizedBox(height: 16),
            Text('Select Power Level'),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _powerLevel = PowerLevel.low;
                    });
                  },
                  child: FadeTransition(
                    opacity: _powerLevelAnimation,
                    child: Text('Low', style: TextStyle(fontSize: 20)),
                  ),
                ),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _powerLevel = PowerLevel.medium;
                    });
                  },
                  child: Text('Medium', style: TextStyle(fontSize: 20)),
                ),
                SizedBox(width: 16),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _powerLevel = PowerLevel.high;
                    });
                  },
                  child: FadeTransition(
                    opacity: _powerLevelAnimation,
                    child: Text('High', style: TextStyle(fontSize: 20)),
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),
            TextField(
              onChanged: (value) {
                setState(() {
                  _ipAddress = value;
                });
              },
              decoration: InputDecoration(
                labelText: 'NodeMCU IP Address',
              ),
            ),
            ElevatedButton(
              onPressed: _storeInitialDirection,
              child: Text('Store Initial Direction'),
            ),
            ElevatedButton(
              onPressed: _startSendingData,
              child: Text('Connect to NodeMCU and Send Data'),
            ),
            ElevatedButton(
              onPressed: _disconnectNodeMCU,
              child: Text('Disconnect from NodeMCU'),
            ),
          ],
        ),
      ),
    );
  }
}