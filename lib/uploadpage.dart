import 'package:flutter/material.dart';
import 'dart:io';

class UploadPage extends StatelessWidget {
  UploadPage(this.image, this.getImage, this.returnToUpload, this.gallery);
  final File image;
  final Function getImage;
  final bool gallery;
  final Function returnToUpload;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ElevatedButton(
            child: new Text(
              "Back",
              style: TextStyle(fontSize: 12),
            ),
            onPressed: returnToUpload,
          ),
          ElevatedButton(
            child: Text('Upload an image'),
            onPressed: () {
              getImage(gallery);
            },
          ),
          image == null ? Text("No image") : Container(
              child: Image.file(image)
          ),
        ],
      ),
    );

  }
}