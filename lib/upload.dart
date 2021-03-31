import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:firebase_storage/firebase_storage.dart' as firebase_storage;
import 'package:firebase_core/firebase_core.dart' as firebase_core;
import 'dart:math';
import 'thumbnails.dart';
import 'package:dio/dio.dart';
import 'uploadpage.dart';

const _chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
Random _rnd = Random();

String getRandomString(int length) => String.fromCharCodes(Iterable.generate(
    length, (_) => _chars.codeUnitAt(_rnd.nextInt(_chars.length))));


class UploadWidget extends StatefulWidget {
  @override
  _UploadWidgetState createState() => _UploadWidgetState();
}

class _UploadWidgetState extends State<UploadWidget> {

  File _image;
  String uploadName;
  List<String> _imageList;
  List<String> _imageNameList;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    asyncMethods();
  }

  void asyncMethods() async {
    firebase_storage.FirebaseStorage storage = firebase_storage.FirebaseStorage.instanceFor(bucket: 'flutter-deg-public');
    firebase_storage.Reference ref = storage.ref('/converted');
    firebase_storage.ListResult result = await ref.listAll();
    List<String> imageList = [];
    List<String> imageNameList = [];
    result.items.forEach((firebase_storage.Reference ref) async {
      imageList.add(await ref.getDownloadURL());
      imageNameList.add(ref.name);
    });

    setState(() {
      _imageList = imageList;
      _imageNameList = imageNameList;
    });
  }

  Future getImage(bool gallery) async {
    User user = FirebaseAuth.instance.currentUser;
    uploadName = getRandomString(7) + "_" + user.uid + '.jpg';

    ImagePicker picker = ImagePicker();
    PickedFile pickedFile;

    if(gallery) {
      pickedFile = await picker.getImage(
        source: ImageSource.gallery,);
    }
    else{
      pickedFile = await picker.getImage(
        source: ImageSource.camera,);
    }

    if (pickedFile != null) {
      try {
        await firebase_storage.FirebaseStorage.instance.ref()
            .child(uploadName)
            .putFile(File(pickedFile.path));

        setState(() {
          _image = File(pickedFile.path);
        });
      } on firebase_core.FirebaseException catch (e) {
        print(e);
      }
    } else {
      print('No image selected.');
    }
  }

  void buttonPressed() async {
    UserCredential userCredential = await FirebaseAuth.instance.signInAnonymously();
    print(userCredential);
  }

  void dbImages() {
    setState(() {
      _currentIndex = 1;
    });
  }

  void returnToUpload() {
    setState(() {
      _currentIndex = 0;
    });
  }

  void uploadFromGallery() {
    setState(() {
      _currentIndex = 2;
    });
  }

  void uploadFromCamera() {
    setState(() {
      _currentIndex = 3;
    });
  }

  Future<void> removeImage(id) async {
    var dio = Dio();
    Response response = await dio.post('https://asia-east2-flutter-deg.cloudfunctions.net/apppRemoveImage', data: {"payload" : id});
    print(response.data.toString());
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> _children = [
      ListView(
        children: <Widget>[
          Card(child: ListTile(title: Text('Options'))),
          Card(
            child: ListTile(
              onTap: buttonPressed,
              leading: FlutterLogo(),
              title: Text('Profile'),
            ),
          ),
          Card(
            child: ListTile(
              onTap: uploadFromGallery,
              leading: FlutterLogo(),
              title: Text('Upload from Gallery'),
            ),
          ),
          Card(
            child: ListTile(
              onTap: uploadFromCamera,
              leading: FlutterLogo(),
              title: Text('Upload from Camera'),
            ),
          ),
          Card(
            child: ListTile(
              onTap: dbImages,
              leading: FlutterLogo(),
              title: Text('See database images'),
            ),
          ),
        ],
      ),
      ThumbnailList(_imageList, _imageNameList, returnToUpload, removeImage),
      UploadPage(_image, getImage, returnToUpload, true),
      UploadPage(_image, getImage, returnToUpload, false),
    ];

    return _children[_currentIndex];
  }
}