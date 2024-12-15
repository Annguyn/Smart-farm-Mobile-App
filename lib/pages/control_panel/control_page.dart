import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:async';

class ControlPage extends StatefulWidget {
  @override
  _ControlPageState createState() => _ControlPageState();
}

class _ControlPageState extends State<ControlPage>
    with SingleTickerProviderStateMixin {
  bool isCurtainOpen = false;
  bool isPumpOn = false;
  bool isAutomaticFan = false;
  bool isLightOn = false;
  bool isAutomaticLight = false;
  bool isAutomaticCurtain = false;
  bool isAutomaticPump = false;
  bool isCurtainInProgress = false;
  double fanSpeed = 0;
  Timer? _debounce;
  Timer? _timer;

  late AnimationController _fanController;

  @override
  void initState() {
    super.initState();
    fetchData();
    _fanController =
    AnimationController(vsync: this, duration: Duration(seconds: 1))
      ..repeat();
    _timer = Timer.periodic(Duration(seconds: 5), (timer) {
      fetchData();
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _fanController.dispose();
    super.dispose();
  }

  void fetchData() async {
    try {
      final response = await http.get(Uri.parse('http://your-api-url/data'));
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          isAutomaticFan = data['automaticFan'] == 1;
          isAutomaticCurtain = data['automaticCurtain'] == 1;
          isAutomaticPump = data['automaticPump'] == 1;
          isAutomaticLight = data['automaticLight'] == 1;
          isLightOn = data['ledStatus'] == 1;
          isPumpOn = data['pumpStatus'] == 1;
          isCurtainOpen = data['curtainStatus'] == 1;
          fanSpeed = (data['fanStatus'] as num).toDouble();
        });
      } else {
        showSnackbar('Error: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      showSnackbar('Error: $e');
    }
  }

  void showSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> sendCommand(String endpoint, String message) async {
    try {
      final url = Uri.parse('http://your-api-url/$endpoint');
      final response = await http.post(url, body: '');
      if (response.statusCode == 200) {
        fetchData();
      } else {
        showSnackbar('Error: ${response.statusCode} ${response.reasonPhrase}');
      }
    } catch (e) {
      showSnackbar('Error: $e');
    }
  }

  void _onFanSpeedChanged(double value) {
    setState(() {
      fanSpeed = value;
    });

    if (_debounce?.isActive ?? false) _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () {
      sendCommand('fan/set?speed=${value.round()}', 'Setting Fan Speed');
    });
  }

  void _onCurtainSwitchChanged(bool value) {
    setState(() {
      isCurtainOpen = value;
      isCurtainInProgress = true;
    });
    sendCommand(
      value ? 'curtain/open' : 'curtain/close',
      value ? 'Opening Curtain' : 'Closing Curtain',
    );
    Timer(Duration(minutes: 1), () {
      setState(() {
        isCurtainInProgress = false;
      });
    });
  }

  void _onLightSwitchChanged(bool value) {
    setState(() {
      isLightOn = value;
    });
    sendCommand(
      value ? 'led/on' : 'led/off',
      value ? 'Turning On Light' : 'Turning Off Light',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Control Panel'),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [Colors.blueAccent, Colors.greenAccent],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: ListView(
          children: [
            controlCard(
              icon: Icons.lightbulb_outline,
              label: 'Light',
              color: Colors.yellow,
              status: isLightOn ? "On" : "Off",
              child: Switch(
                value: isLightOn,
                onChanged: isAutomaticLight ? null : _onLightSwitchChanged,
              ),
            ),
            controlCard(
              icon: Icons.curtains,
              label: 'Curtain',
              color: Colors.orange,
              status: isCurtainOpen ? "Open" : "Closed",
              child: Switch(
                value: isCurtainOpen,
                onChanged: isAutomaticCurtain || isCurtainInProgress
                    ? null
                    : _onCurtainSwitchChanged,
              ),
            ),
            controlCard(
              icon: Icons.speed,
              label: 'Fan Speed',
              color: Colors.blue,
              status: '${fanSpeed.round()}',
              child: Stack(
                alignment: Alignment.center,
                children: [
                  RotationTransition(
                    turns: _fanController,
                    child: Icon(Icons.toys, size: 80, color: Colors.blue[300]),
                  ),
                  Slider(
                    value: fanSpeed,
                    min: 0,
                    max: 255,
                    divisions: 255,
                    label: fanSpeed.round().toString(),
                    onChanged: isAutomaticFan ? null : _onFanSpeedChanged,
                  ),
                ],
              ),
            ),
            controlCard(
              icon: Icons.water_drop,
              label: 'Pump',
              color: Colors.green,
              status: isPumpOn ? "On" : "Off",
              child: Stack(
                children: [
                  AnimatedOpacity(
                    opacity: isPumpOn ? 1.0 : 0.0,
                    duration: Duration(seconds: 1),
                    child: Image.asset(
                      'assets/water_flow.gif',
                      height: 60,
                      width: 60,
                      fit: BoxFit.contain,
                    ),
                  ),
                  Switch(
                    value: isPumpOn,
                    onChanged: isAutomaticPump
                        ? null
                        : (value) {
                      setState(() {
                        isPumpOn = value;
                      });
                      sendCommand(
                        value ? 'pump/on' : 'pump/off',
                        value ? 'Turning On Pump' : 'Turning Off Pump',
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget controlCard({
    required IconData icon,
    required String label,
    required Color color,
    required String status,
    required Widget child,
  }) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 6,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color.withOpacity(0.3), color],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              Icon(icon, size: 50, color: Colors.white),
              SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 5),
                    Text(
                      'Status: $status',
                      style: TextStyle(fontSize: 16, color: Colors.white70),
                    ),
                    SizedBox(height: 10),
                    child,
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
