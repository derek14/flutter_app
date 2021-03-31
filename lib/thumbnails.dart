import 'package:flutter/material.dart';

class ThumbnailList extends StatelessWidget {
  ThumbnailList(this.imageList, this.imageNameList, this.returnToUpload, this.removeImage);
  final List<String> imageList;
  final List<String> imageNameList;
  final Function returnToUpload;
  final Function removeImage;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          height: 50,
          child: ElevatedButton(
            child: new Text(
              "Back",
              style: TextStyle(fontSize: 12),
            ),
            onPressed: returnToUpload,
          ),
        ),
        imageList == null
            ? Text("No image db")
            : Container(
              height: MediaQuery.of(context).size.height - 200,
              child: ListView.builder(
                  shrinkWrap: true,
                  itemBuilder: (BuildContext ctx, int index) {
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundImage: NetworkImage(imageList[index]),
                      ),
                      title: Text(imageNameList[index]),
                      subtitle: Text('Click to remove'),
                      trailing: Icon(Icons.keyboard_arrow_right),
                      onTap: () => removeImage(imageNameList[index]),
                    );
                  },
                  itemCount: imageList.length,
                ),
            ),
      ],
    );
  }
}
//
// Image.network(imageList[index]);