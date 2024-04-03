import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:typed_data';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'HMI',
      theme: ThemeData(
        colorScheme: const ColorScheme.dark(
          primary: Colors.white,
          onPrimary: Colors.blue,
          secondary: Colors.blue,
          onSecondary: Colors.white,
        ),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'HMI'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  var availablePorts = SerialPort.availablePorts;
  SerialPortReader? portreader;
  String? currentPort;
  SerialPort? port;
  Uint8List? data;
  int baudrate = 115200;

  void updatePorts() {
    setState(() {
      currentPort = null;
      availablePorts = SerialPort.availablePorts;
    });
  }

  List<double> counters = [0, 0];
  bool corr = false;
  TextEditingController baudrateController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    baudrateController.text = baudrate.toString();
    return Scaffold(
      body: Center(
        child: Column(
          children: [
            const SizedBox(height: 50),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                DropdownButton<String>(
                  borderRadius: BorderRadius.circular(10),
                  padding: const EdgeInsets.only(left: 10, right: 10),
                  value: currentPort,
                  items: availablePorts.map((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(value),
                    );
                  }).toList(),
                  onChanged: (String? newValue) {
                    setState(() {
                      port?.close();
                      setState(() {
                        currentPort = null;
                      });
                      currentPort = newValue;
                      var portconfig = SerialPortConfig();
                      portconfig.baudRate = baudrate;
                      portconfig.bits = 8;
                      portconfig.stopBits = 1;
                      portconfig.parity = SerialPortParity.none;
                      port = SerialPort(newValue!);
                      port!.open(mode: SerialPortMode.read);
                      port!.config = portconfig;
                      portreader = SerialPortReader(port!);
                    });
                  },
                ),
                const SizedBox(width: 70),
                Container(
                  width: 100,
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Baudrate',
                    ),
                    controller: baudrateController,
                    onChanged: (String value) {
                      try {
                        baudrate = int.parse(value);
                      } catch (e) {
                        baudrate = 115200;
                      }
                    },
                  ),
                ),
                TextButton(
                  onPressed: updatePorts,
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  child: const Text('Refresh'),
                ),
                const SizedBox(width: 20),
                TextButton(
                  onPressed: () {
                    port!.close();
                    port!.dispose();
                    setState(() {
                      currentPort = null;
                    });
                  },
                  style: TextButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.secondary,
                  ),
                  child: const Text('Close Port'),
                ),
              ],
            ),
            const SizedBox(height: 125),
            Center(
              child: Container(
                width: 740,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: currentPort == null
                      ? Theme.of(context).colorScheme.background
                      : Colors.grey[900],
                ),
                child: StreamBuilder<Uint8List>(
                  stream: portreader?.stream,
                  builder: (context, snapshot) {
                    if (snapshot.hasData) {
                      var bindata = snapshot.data;
                      var data = String.fromCharCodes(bindata!);
                      data = data.replaceAll('Â', '');
                      var fields = data.split(' ');
                      var date = fields[0];
                      var time = fields[1];
                      var fix = fields[2] == '0' ? 'Searching' : 'Locked';
                      var lat = fields[3];
                      var lon = fields[4];
                      var alt = fields[5];
                      return Text(
                        'Date: $date\nTime: $time\nFix: $fix\nLatitude: $lat\nLongitude: $lon\nAltitude: $alt',
                        style: const TextStyle(
                          fontSize: 20,
                        ),
                      );
                      /*Row(
                        children: [
                          SfRadialGauge(
                            title: GaugeTitle(text: 'Angle ${numdata[0]}°'),
                            axes: <RadialAxis>[
                              RadialAxis(
                                minimum: 0,
                                maximum: 360,
                                ranges: <GaugeRange>[
                                  GaugeRange(
                                      startValue: 0,
                                      endValue: 360,
                                      color: Colors.blue),
                                ],
                                pointers: <GaugePointer>[
                                  NeedlePointer(
                                    value: numdata[0],
                                    needleColor: Colors.orange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(width: 50),
                          Column(
                            children: [
                              Text('Distance: ${numdata[1]} cm'),
                              const SizedBox(height: 50),
                              SfLinearGauge(
                                orientation: LinearGaugeOrientation.horizontal,
                                minimum: 0,
                                maximum: 100,
                                ranges: const <LinearGaugeRange>[
                                  LinearGaugeRange(
                                      startValue: 0,
                                      endValue: 100,
                                      color: Colors.blue),
                                ],
                                barPointers: [
                                  LinearBarPointer(
                                    value: numdata[1],
                                    color: Colors.orange,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      );*/
                    } else {
                      return const Text('');
                    }
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
