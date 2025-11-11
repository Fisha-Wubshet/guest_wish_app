import 'package:flutter/material.dart';
import 'package:flutter/src/foundation/key.dart';
import 'package:flutter/src/widgets/framework.dart';
import 'package:flutter/src/widgets/placeholder.dart';
import 'package:guest_wish_app/Utils/brandColor.dart';
import 'package:guest_wish_app/main.dart';


class SelectLocation extends StatefulWidget {


  @override
  State<SelectLocation> createState() => _SelectLocationState();
}

class _SelectLocationState extends State<SelectLocation> {
  var selectedValue;


  @override
  Widget build(BuildContext context) {
    return Scaffold(
backgroundColor: backgroundColor,
      appBar: AppBar(
        elevation: 0,
        backgroundColor:backgroundColor,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
           crossAxisAlignment: CrossAxisAlignment.center,
           mainAxisAlignment: MainAxisAlignment.center,
      
          children: [
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(Icons.language, size: 40,),
                  SizedBox(height: 10,),
                  Align(
                    alignment: Alignment.center,
                    child: Text(
                                                'ቋንቋ ይምረጡ\nLanguage Selection',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 18,
                                                    fontFamily: 'Inter',
                                                    fontWeight: FontWeight.w900),
                                                    textAlign: TextAlign.center,
                                              ),
                  ),
                  SizedBox(height: 10,),
                  Text(
                                                'እባኮትን የሚፈልጉትን ቋንቋ (እንግሊዝኛ ወይም አማርኛ) አንዱን ይምረጡ።\nChoose your preferred language (English or Amharic) to continue. ',
                                                style: TextStyle(
                                                    color: Colors.black,
                                                    fontSize: 14,
                                                    fontFamily: 'Inter',
                                                  ),
                                                  textAlign: TextAlign.center,
                                              ),
                                               SizedBox(height: 20,),
                                              selectedList(
                                                'አማርኛ', 
                                                'Amharic',
                                                'Amharic'),
                                                 SizedBox(height: 15,),
                                                 selectedList(
                                                'English', 
                                                'እንግሊዝኛ',
                                                'English')
                ],
              ),
            ),
            // selectingButton(selectedValue!=null),
          ],
        ),
      ),
    );
  }
  selectLocationMethod(value){
    setState(() {
      selectedValue=value;
    });
//   Navigator.pushReplacement(
//   context,
//   MaterialPageRoute(builder: (context) => WishApp(language:  selectedValue)),
// );
  }
  Widget selectedList(title, subtitle, value){
    return GestureDetector(
      onTap: (){
        selectLocationMethod(value);
      },
      child: Container(
         decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7), color: Colors.white,
              boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 2,
            offset: Offset(0, 2), // changes position of shadow
          ),
        ], ),
        child: Padding(
          padding: const EdgeInsets.all(10.0),
          child: Row(
            children: [
              // Icon(Icons.radio_button_off),
              //  Icon(selectedValue==value?Icons.radio_button_checked:Icons.radio_button_off),
               SizedBox(width: 10,),
              // IconButton(onPressed: (){
    
              // }, icon:Icon(selectedValue==title?Icons.radio_button_checked:Icons.radio_button_off)),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.start,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                   Text(
                                                        '$title',
                                                        style: TextStyle(
                                                            color: Colors.black,
                                                            fontSize: 16,
                                                            fontFamily: 'Inter',
                                                            fontWeight: FontWeight.w900),
                                                      ),
                          
                          SizedBox(height: 3,),
                          Text(
                                                        '$subtitle',
                                                        style: TextStyle(
                                                            color: Colors.grey,
                                                            fontSize: 14,
                                                            fontFamily: 'Inter',
                                                          ),
                                                          
                                                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  Widget selectingButton(activeStatus){
return GestureDetector(
  onTap: () async {

    // Get.offAll(HomePage());
  },
  child:   Container(
    height: 50,
    decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(7), color:activeStatus?primaryColor:Colors.white70,
               
              boxShadow: [
          BoxShadow(
            color: Colors.grey.withOpacity(0.05),
            spreadRadius: 2,
            blurRadius: 2,
            offset: Offset(0, 2), // changes position of shadow
          ),
        ], ),
    child:  Align(
      alignment: Alignment.center,
      child: Text(
                                                          'Continue',
                                                          style: TextStyle(
                                                              color: activeStatus?Colors.white:Colors.grey,
                                                              fontSize: 16,
                                                              fontFamily: 'Inter',
                                                              fontWeight: FontWeight.w900),
                                                        ),
    ),
  ),
);
  }
}