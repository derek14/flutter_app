import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'dart:math' as math;
import 'package:tflite/tflite.dart';
import 'package:ml_linalg/linalg.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class CameraApp extends StatefulWidget {
  final List<List<dynamic>> points;
  final List<String> names;
  CameraApp(this.points, this.names);
  // CameraApp({Key key, @required this.points}) : super(key: key);

  @override
  _CameraAppState createState() => _CameraAppState(points, names);
}

class _CameraAppState extends State<CameraApp> {
  List<List<dynamic>> points;
  List<String> names;
  _CameraAppState(this.points, this.names);

  List<CameraDescription> cameras;
  CameraController controller;
  bool isDetecting = false;
  String cossimDisplay = "0.0%";
  String matchOrNot = 'No Match';
  File _imageMatched;
  DateTime _matchedtime;

  @override
  void initState() {
    super.initState();
    asyncMethod();
  }

  Future<double> _calCosineSimilarity(embeddings, trigger) async {
    final trigger_embed = Vector.fromList(trigger);
    final trigger_embed_norm = trigger_embed.normalize(Norm.euclidean);

    final vector_embed = Vector.fromList(embeddings);
    final vector_embed_norm = vector_embed.normalize(Norm.euclidean);

    final numerator = vector_embed_norm.dot(trigger_embed_norm);
    final denominator = vector_embed_norm.norm() * vector_embed_norm.norm();
    final custom_cossim = numerator / denominator * 100;

    return custom_cossim;
  }

  Future<List<MapEntry<int, double>>> _searchThroughEmbeddings(aug_embed) async {
    var mapForStore = <int, double>{};
    for (var i=0; i<widget.points.length; i++) {
      List<double> aug_trigger = widget.points[i].map<double>((val) => val.toDouble()).toList();
      final custom_cossim = await _calCosineSimilarity(aug_embed, aug_trigger);
      mapForStore[i] = custom_cossim;
    }

    var sortedEntries = mapForStore.entries.toList()..sort((e1, e2) {
      var diff = e2.value.compareTo(e1.value);
      if (diff == 0) diff = e2.key.compareTo(e1.key);
      return diff;
    });

    return sortedEntries;
  }

  void asyncMethod() async {
    print("Loaded Camera");
    cameras = await availableCameras();

    controller = CameraController(cameras[0], ResolutionPreset.max);
    controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});

      controller.startImageStream((CameraImage img) {
        if (!isDetecting) {
          isDetecting = true;

          int startTime = new DateTime.now().millisecondsSinceEpoch;

          Tflite.detectObjectOnFrame(
            bytesList: img.planes.map((plane) {
              return plane.bytes;
            }).toList(),
            model: "Deg",
            imageHeight: img.height,
            imageWidth: img.width,
            imageMean: 127.5,
            imageStd: 127.5,
            numResultsPerClass: 1,
            threshold: 0.4,
          ).then((embeddings) async {
            int endTime = new DateTime.now().millisecondsSinceEpoch;
            print("Detection took ${endTime - startTime}");

            List<double> aug_embed = embeddings.map<double>((val) => val.toDouble()).toList();
            var sortedEntries =  await this._searchThroughEmbeddings(aug_embed);

            String _matchOrNot;
            File imageToFile;
            DateTime matchedtime;
            bool _needSetState = false;
            if(this._matchedtime==null) {
              if(sortedEntries[0].value>70.0) {
                _matchOrNot="It's a Match!";
                Directory appDocDir = await getApplicationDocumentsDirectory();
                imageToFile = File('${appDocDir.path}/'+this.names[sortedEntries[0].key]+'.jpg');
                matchedtime = DateTime.now();
              } else {
                _matchOrNot="No Match";
              }
              _needSetState = true;
            } else {
              print(DateTime.now().difference(this._matchedtime).inSeconds);
              if(DateTime.now().difference(this._matchedtime).inSeconds>10.0) {
                if(sortedEntries[0].value>70.0) {
                  _matchOrNot="It's a Match!";
                  Directory appDocDir = await getApplicationDocumentsDirectory();
                  imageToFile = File('${appDocDir.path}/'+this.names[sortedEntries[0].key]+'.jpg');
                  matchedtime = DateTime.now();
                } else {
                  _matchOrNot="No Match";
                }
                _needSetState = true;
              }
            }

            // widget.setRecognitions(recognitions, img.height, img.width);
            if (mounted &&_needSetState) {
              setState(() {
                cossimDisplay=sortedEntries[0].value.toStringAsFixed(2)+"%";
                matchOrNot=_matchOrNot;
                _imageMatched = imageToFile;
                _matchedtime = matchedtime;
              });
            }

            isDetecting = false;
          });
        }
      });
    });
  }

  @override
  void dispose() {
    controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (controller == null || !controller.value.isInitialized) {
      return Container();
    }

    var tmp = MediaQuery.of(context).size;
    var screenH = math.max(tmp.height, tmp.width);
    var screenW = math.min(tmp.height, tmp.width);
    tmp = controller.value.previewSize;
    var previewH = math.max(tmp.height, tmp.width);
    var previewW = math.min(tmp.height, tmp.width);
    var screenRatio = screenH / screenW;
    var previewRatio = previewH / previewW;

    return OverflowBox(
      maxHeight:
      screenRatio > previewRatio ? screenH : screenW / previewW * previewH,
      maxWidth:
      screenRatio > previewRatio ? screenH / previewH * previewW : screenW,
      child: Stack(children:[
        CameraPreview(controller),
      Container(
        alignment: Alignment.center,
        child: Opacity(
          opacity: 0.8,
          child: _imageMatched==null ? Container() : Container(
            margin: EdgeInsets.all(90.0),
            child: Card(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Image.file(_imageMatched, fit: BoxFit.cover,),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: <Widget>[
                      TextButton(
                        child: Text('DISMISS'),
                        onPressed: () {/* ... */},
                      ),
                      SizedBox(width: 8),
                      TextButton(
                        child: Text('GO'),
                        onPressed: () {/* ... */},
                      ),
                      SizedBox(width: 8),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
        Container(
          alignment: Alignment.bottomCenter,
          child: Opacity(
            opacity: 0.6,
            child: Container(
              width: 300,
              margin: EdgeInsets.all(90.0),
              child: Card(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    ListTile(
                      leading: Icon(Icons.album),
                      title: Text(this.matchOrNot),
                      subtitle: Text(this.cossimDisplay),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ]),
    );
  }
}

