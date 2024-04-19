import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_libserialport/flutter_libserialport.dart';
import 'package:syncfusion_flutter_gauges/gauges.dart';
import 'dart:typed_data';

const M = 0.0289644;
const R = 8.31432;
const g = 9.81;
const T = 288.15;
const P = 101325;

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
                      var imu_data = [
                        double.parse(fields[0]),
                        double.parse(fields[1]),
                        double.parse(fields[2]),
                        double.parse(fields[3]),
                        double.parse(fields[4]),
                        double.parse(fields[5]),
                      ];
                      var temp = double.parse(fields[6]);
                      var press = double.parse(fields[7]);
                      var alt = log(P / press) * (R * T) / (M * g);
                      // imu_data 0 to 2 are accel values from -4 to 4 g
                      // imu_data 3 to 5 are gyto values from -250 to 250 deg/s
                      var accmin = -1.0;
                      var accmax = 1.0;
                      var gyromin = -250.0;
                      var gyromax = 250.0;
                      return Scrollable(
                          viewportBuilder: (BuildContext context, _) {
                        return Column(children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              //x y then z with labels
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'X Acc: ${imu_data[0].toStringAsFixed(2)} g',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: accmin,
                                      maximum: accmax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: accmin,
                                            endValue: accmax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[0],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'Y Acc: ${imu_data[1].toStringAsFixed(2)} g',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: accmin,
                                      maximum: accmax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: accmin,
                                            endValue: accmax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[1],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'Z Acc: ${imu_data[2].toStringAsFixed(2)} g',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: accmin,
                                      maximum: accmax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: accmin,
                                            endValue: accmax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[2],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                'Altitude:\n${alt.toStringAsFixed(2)} m',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                              Container(
                                height: 300,
                                child: SfLinearGauge(
                                  orientation: LinearGaugeOrientation.vertical,
                                  axisTrackStyle: const LinearAxisTrackStyle(
                                      thickness: 10,
                                      color: Colors.transparent,
                                      edgeStyle: LinearEdgeStyle.bothFlat),
                                  barPointers: <LinearBarPointer>[
                                    LinearBarPointer(
                                      value: alt,
                                      color: Colors.cyan,
                                      thickness: 10,
                                      edgeStyle: LinearEdgeStyle.bothFlat,
                                      position: LinearElementPosition.outside,
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                            children: [
                              //x y then z with labels
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'X Gyro: ${imu_data[3].toStringAsFixed(2)} °/s',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: gyromin,
                                      maximum: gyromax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: gyromin,
                                            endValue: gyromax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[3],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'Y Gyro: ${imu_data[4].toStringAsFixed(2)} °/s',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: gyromin,
                                      maximum: gyromax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: gyromin,
                                            endValue: gyromax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[4],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 150,
                                child: SfRadialGauge(
                                  title: GaugeTitle(
                                      text:
                                          'Z Gyro: ${imu_data[5].toStringAsFixed(2)} °/s',
                                      textStyle: const TextStyle(
                                          fontSize: 16, color: Colors.white)),
                                  axes: <RadialAxis>[
                                    RadialAxis(
                                      minimum: gyromin,
                                      maximum: gyromax,
                                      showLastLabel: true,
                                      ranges: <GaugeRange>[
                                        GaugeRange(
                                            startValue: gyromin,
                                            endValue: gyromax,
                                            color: Colors.cyan,
                                            startWidth: 10,
                                            endWidth: 10),
                                      ],
                                      pointers: <GaugePointer>[
                                        NeedlePointer(
                                            value: imu_data[5],
                                            enableAnimation: true,
                                            animationDuration: 1000,
                                            animationType: AnimationType.ease,
                                            needleColor: Colors.white,
                                            needleStartWidth: 1,
                                            needleEndWidth: 5,
                                            needleLength: 0.8,
                                            knobStyle: const KnobStyle(
                                                knobRadius: 0.1,
                                                sizeUnit: GaugeSizeUnit.factor,
                                                borderColor: Colors.white,
                                                color: Colors.white,
                                                borderWidth: 0.05)),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(
                                width: 15,
                              ),
                              Text(
                                'Temperature:\n${temp.toStringAsFixed(2)} °C',
                                style: const TextStyle(
                                    fontSize: 16, color: Colors.white),
                              ),
                              Container(
                                height: 300,
                                child: SfLinearGauge(
                                  orientation: LinearGaugeOrientation.vertical,
                                  axisTrackStyle: const LinearAxisTrackStyle(
                                      thickness: 10,
                                      color: Colors.transparent,
                                      edgeStyle: LinearEdgeStyle.bothFlat),
                                  barPointers: <LinearBarPointer>[
                                    LinearBarPointer(
                                      value: temp,
                                      color: Colors.cyan,
                                      thickness: 10,
                                      edgeStyle: LinearEdgeStyle.bothFlat,
                                      position: LinearElementPosition.outside,
                                    )
                                  ],
                                ),
                              )
                            ],
                          ),
                        ]);
                      });
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
