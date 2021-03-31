import 'dart:io';
import 'package:flutter/material.dart';

class InferenceOnImage extends StatelessWidget {
  InferenceOnImage(this.image, this.finalCossim, this.imageMatched);
  final File image;
  final String finalCossim;
  final File imageMatched;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          imageMatched ==null ? Container() : Card(child: ListTile(title: Text("Similarity ratio: "+finalCossim))),
          imageMatched ==null ? Text('No image selected') : Container(
            height: 250,
            child: Card(
              color: Colors.white,
              child: Row(
                children: [
                  Expanded(
                    flex: 50,
                    child: Image.file(image, height: 224, width: 224, fit: BoxFit.cover,),
                  ),
                  Expanded(
                    flex: 50,
                    child: Image.file(imageMatched, height: 224, width: 224, fit: BoxFit.cover,),
                  ),
                ],
              ),
            ),
          ),
          // imageMatched ==null ? Container() : Image.file(imageMatched),
        ],
      ),
    );
  }
}
//
//
