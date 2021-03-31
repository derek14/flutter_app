import 'dart:io';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:tflite/tflite.dart';
import 'package:ml_linalg/linalg.dart';

import "trigger.dart";
import 'inferonimage.dart';
import 'camera.dart';
import 'upload.dart';

import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:path_provider/path_provider.dart';
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:modal_bottom_sheet/modal_bottom_sheet.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(App());
}

class App extends StatelessWidget {
  // Create the initialization Future outside of `build`:
  final Future<FirebaseApp> _initialization = Firebase.initializeApp();

  @override
  Widget build(BuildContext context) {
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
    ]);
    return FutureBuilder(
      future: _initialization,
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Container();
        }
        if (snapshot.connectionState == ConnectionState.done) {
          return MyApp();
        }
        return Container();
      },
    );
  }
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primaryColor: Colors.black,
      ),
      home: MyHomePage(title: 'DEG Experiement'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);

  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  int _currentIndex = 0;
  File _image;
  File _imageMatched;
  final picker = ImagePicker();
  String finalCossim = "0.0%";
  List<List<dynamic>> _points;
  List<String> _names;

  @override
  void initState() {
    super.initState();
    asyncLoadEmbeddings();
    asyncMethod();

    FirebaseAuth.instance
        .authStateChanges()
        .listen((User user) {
      if (user == null) {
        print('User is currently signed out!');
      } else {
        print('User is signed in!');
      }
    });
  }

  void asyncLoadEmbeddings() async {
    Directory appDocDir = await getApplicationDocumentsDirectory();
    File embeddingsToFile = File('${appDocDir.path}/embeddings.json');
    File namesToFile = File('${appDocDir.path}/names.json');

    try {
      await firebase_storage.FirebaseStorage.instanceFor(bucket: 'flutter-deg-public')
          .ref('/embeddings/test.json')
          .writeToFile(embeddingsToFile);

      String embeddingsContents = await embeddingsToFile.readAsString();
      final embeddingsJsonResponse = jsonDecode(embeddingsContents) as Map;

      await firebase_storage.FirebaseStorage.instanceFor(bucket: 'flutter-deg-public')
          .ref('/names/test.json')
          .writeToFile(namesToFile);

      String namesContents = await namesToFile.readAsString();
      final namesJsonResponse = jsonDecode(namesContents) as Map;

      List<String> names = [];
      for (final v in namesJsonResponse.values) {
        names.add(v);
      }

      List<List<dynamic>> points = [];

      for (final v in embeddingsJsonResponse.values) {
        points.add(json.decode(v).toList()[0]);
      }
      print(names);
      setState(() {
        _points = points;
        _names = names;
      });

    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }
  }

  void asyncMethod() async {
    print("Loaded");
    await Tflite.loadModel(model: "assets/deg.tflite");
  }

  void onTabTapped(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  Future getImage(imgSource) async {
    print("Here");
    // final pickedFile = await picker.getImage(source: ImageSource.camera);
    final pickedFile = await picker.getImage(source: imgSource);
    final compareEmeddings = await _compareEmbeddings(pickedFile.path);

    Directory appDocDir = await getApplicationDocumentsDirectory();
    File imageToFile = File('${appDocDir.path}/'+compareEmeddings[1]+'.jpg');

    try {
      await firebase_storage.FirebaseStorage.instanceFor(bucket: 'flutter-deg-public')
          .ref('/converted/'+compareEmeddings[1]+'.jpg')
          .writeToFile(imageToFile);
    } on firebase_core.FirebaseException catch (e) {
      print(e);
    }
    print(compareEmeddings[1]);

    setState(() {
      if (pickedFile != null) {
        _image = File(pickedFile.path);
        finalCossim = compareEmeddings[0].toStringAsFixed(2)+"%";
        _imageMatched = imageToFile;
      } else {
        print('No image selected');
      }
    });
  }

  Future<List<MapEntry<int, double>>> _searchThroughEmbeddings(aug_embed) async {
    var mapForStore = <int, double>{};
    for (var i=0; i<this._points.length; i++) {
      List<double> aug_trigger = this._points[i].map<double>((val) => val.toDouble()).toList();
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

  Future<List> _compareEmbeddings(filepath) async {
    List embeddings = await Tflite.runDegOnImages(
        triggerPath: filepath, // required
        imageMean: 127.5,
        imageStd: 127.5
    );

    List<double> aug_embed = embeddings.map<double>((val) => val.toDouble()).toList();
    var sortedEntries =  await _searchThroughEmbeddings(aug_embed);

    return [sortedEntries[0].value, this._names[sortedEntries[0].key]];
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

  @override
  Widget build(BuildContext context) {
    final List<Widget> _children = [
      InferenceOnImage(this._image, this.finalCossim, this._imageMatched),
      CameraApp(this._points, this._names),
      UploadWidget(),
    ];

    final List<Widget> _fabchildren = [
      FloatingActionButton(
        onPressed: () => showMaterialModalBottomSheet(
          expand: false,
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => ModalFit(getImage),
        ),
        tooltip: 'Pick Image',
        child: Icon(Icons.upload_outlined),
        backgroundColor: Colors.black,
      ),
      null,
      null,
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: _children[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
          onTap: onTabTapped,
          fixedColor: Colors.black,
          currentIndex: _currentIndex,
          items: [
            BottomNavigationBarItem(icon: Icon(Icons.image), label: 'Image'),
            BottomNavigationBarItem(icon: Icon(Icons.video_call_rounded), label: "Frame"),
            BottomNavigationBarItem(icon: Icon(Icons.settings), label: "Settings")
          ]
      ),
      floatingActionButton: _fabchildren[_currentIndex],
    );
  }
}

class ModalFit extends StatelessWidget {
  ModalFit(this.getImage);
  final Function getImage;

  @override
  Widget build(BuildContext context) {
    return Material(
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ListTile(
                title: Text('From Gallery'),
                leading: Icon(Icons.image),
                onTap: () async {
                  await getImage(ImageSource.gallery);
                  Navigator.of(context).pop();
                  },
              ),
              ListTile(
                title: Text('From Camera'),
                leading: Icon(Icons.camera_alt),
                onTap: () async {
                  await getImage(ImageSource.camera);
                  Navigator.of(context).pop();
                },
              ),
            ],
          ),
        ));
  }
}