import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:fluttertoast/fluttertoast.dart';
import 'package:google_ml_kit/google_ml_kit.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  cameras = await availableCameras();
  runApp(CameraApp());
}

class CameraApp extends StatefulWidget {
  @override
  _CameraAppState createState() => _CameraAppState();
}

class _CameraAppState extends State<CameraApp> {

  CameraController? controller;
  final imageLabeler = GoogleMlKit.vision.imageLabeler();
  bool canDetect = false;
  final FlutterTts tts = FlutterTts();


  String detectedObject = "No object found";
  double detectedAccuracy = 0;

  @override
  void initState() {
    super.initState();
    tts.setLanguage('en');
    tts.setSpeechRate(0.4);
    Timer.periodic(new Duration(seconds: 5), (timer) {
      debugPrint(timer.tick.toString());
      setState(() {
        detectedObject = "No object found";
        canDetect = true;
        Timer(const Duration(milliseconds: 40), () {
          canDetect = false;
        });
      });
    });
    controller = CameraController(cameras![0], ResolutionPreset.max);
    controller!.initialize().then((_) {
      if (!mounted) {
        return;
      }
      controller!.startImageStream(_processCameraImage);
      setState(() {
        });
      });
  }

  @override
  void dispose() {
    controller!.stopImageStream();
    controller!.stopVideoRecording();
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!controller!.value.isInitialized) {
      return Container();
    }
    return MaterialApp(
        home:
        Scaffold(
            appBar: AppBar(
                backgroundColor: Colors.black,
                title: Text("iView"),
                automaticallyImplyLeading: false
            ),
            body: Stack(
              children: [
                CameraPreview(controller!),
            Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[
                // Your elements here
                Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.vertical(top : Radius.circular(20)),
                    color: Colors.black,
                  ),
                  alignment: Alignment.center,
                  height: 200,
                  padding: EdgeInsets.all(14),
                  child: Column(
                    children: [
                      Text(detectedObject, style: TextStyle(color: Colors.white),),
                      Text(detectedAccuracy.toString(), style: TextStyle(color: Colors.green),),
                    ],
                  )
                )
                 
              ],
            ),

              ],
            )
    ));
  }

  Future _processCameraImage(CameraImage image) async {

    if(!canDetect) {
      return;
    }

    final WriteBuffer allBytes = WriteBuffer();
    for (Plane plane in image.planes) {
      allBytes.putUint8List(plane.bytes);
    }
    final bytes = allBytes.done().buffer.asUint8List();

    final Size imageSize =
    Size(image.width.toDouble(), image.height.toDouble());

    final camera = cameras![0];
    final imageRotation =
        InputImageRotationMethods.fromRawValue(camera.sensorOrientation) ??
            InputImageRotation.Rotation_0deg;

    final inputImageFormat =
        InputImageFormatMethods.fromRawValue(image.format.raw) ??
            InputImageFormat.NV21;

    final planeData = image.planes.map(
          (Plane plane) {
        return InputImagePlaneMetadata(
          bytesPerRow: plane.bytesPerRow,
          height: plane.height,
          width: plane.width,
        );
      },
    ).toList();

    final inputImageData = InputImageData(
      size: imageSize,
      imageRotation: imageRotation,
      inputImageFormat: inputImageFormat,
      planeData: planeData,
    );

    final inputImage =
    InputImage.fromBytes(bytes: bytes, inputImageData: inputImageData);

   // widget.onImage(inputImage);

    final List<ImageLabel> labels = await imageLabeler.processImage(inputImage);
    if(labels.isNotEmpty){
      setState(() {
        detectedObject = "";
      });
    }
    detectedAccuracy = 0;
     for (ImageLabel label in labels) {
      final String labelText = label.label;
      final int index = label.index;
      final double confidence = label.confidence;

      print(label.label + " " + confidence.toString());
      if(label.confidence>0.5) {
        setState(() {
        detectedObject += labelText + " ";
        if(detectedAccuracy==0){
          detectedAccuracy = label.confidence;
          tts.speak(label.label);
        }

      });
      }

    }


/*
    Fluttertoast.showToast(
        msg: labels.first.label,
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.CENTER,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.black,
        textColor: Colors.white,
        fontSize: 16.0
    );
     */
  }

}
