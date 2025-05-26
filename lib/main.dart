import 'dart:math';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  tz.initializeTimeZones();
  await initializeNotifications();
  await requestNotificationPermission();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      home: NavigationScreen(),
    );
  }
}

class NavigationScreen extends StatefulWidget {
  @override
  _NavigationScreenState createState() => _NavigationScreenState();
}

class _NavigationScreenState extends State<NavigationScreen> {
  int _selectedIndex = 0;
  final List<String> _titles = ["General", "Station", "Calibration", "Phasing", "Disclaimer"];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold,fontStyle: FontStyle.italic),),
          ],),
        // title: Text("NavCal Pro"),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.black,

        centerTitle: true,
      ),
      body: 
      // Container(
      //   decoration: BoxDecoration(
      //     image: DecorationImage(image: AssetImage('assets/splash.jpg'),fit: BoxFit.scaleDown,opacity: 0.5),
      //   ),
      // child:
      Column(
        children: [
          Container(
            padding: EdgeInsets.all(10),
            child: Text(
              _titles[_selectedIndex],
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
          ),
          Expanded(
            child: _selectedIndex == 0
                  ? GeneralScreen()
                  : _selectedIndex == 1
                  ? StationScreen()
                  : _selectedIndex == 2
                  ? CalibrationScreen()
                  : _selectedIndex == 3
                  ? PhasingScreen()
                  : _selectedIndex == 4
                    ? DisclaimerScreen()
                    : Center(child: Text("Will update soon.")),
          ),
        ],
      ),
      // ),
      bottomNavigationBar: BottomNavigationBar(
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "General"),
          BottomNavigationBarItem(icon: Icon(Icons.location_on), label: "Station"),
          BottomNavigationBarItem(icon: Icon(Icons.build), label: "Calibration"),
          BottomNavigationBarItem(icon: Icon(Icons.tune), label: "Phasing"),
          BottomNavigationBarItem(icon: Icon(Icons.info), label: "Disclaimer"),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        onTap: _onItemTapped,
      ),
    );
  }
}

class CalibrationScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child:Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        CalibrationButton("Localizer", context),
        CalibrationButton("Glide Path", context),
        CalibrationButton("DVOR", context),
        CalibrationButton("DME", context),
      ],
      ),
    );
  }
}

Widget CalibrationButton(String title, BuildContext context) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: 
    SizedBox(
      width: 200,
      child: 
    ElevatedButton(
      onPressed: () {
        if(title == "Localizer"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => LocalizerScreen())
          );
        }
        else if(title == "Glide Path"){
          Navigator.push(context,
           MaterialPageRoute(builder: (context) => NPOScreen())
          );
        }
        else{
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => CalibrationDetailScreen(title)),
        );
        }
      },
      child: Text(title, style: TextStyle(fontSize: 18)),
    ),
  ));
}

class CalibrationDetailScreen extends StatelessWidget {
  final String title;
  CalibrationDetailScreen(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(title),
      ),
      body: Center(
        child: Text("Details for $title will be updated soon."),
      ),
    );
  }
}

class DisclaimerScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
//             ElevatedButton(
//   onPressed: () async {
//     print('Test button pressed');
//     await showImmediateNotification('Test', 'This is a test notification');
//     print('Test notification should be shown');
//   },
//   child: Text('Test Notification'),
// ),
            Text(
              "About the Application :",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),              
            ),
            SizedBox(height: 8,),
            Text(
              "This application is designed to assist with flight calibration of navigational aids specific to NPO RTS ILS734, NORMARC 7014B/7034B ILS, MOPIENS DVOR V2.0, and MOPIENS DME V2.0",
              style: TextStyle(fontSize: 16),              
            ),
            SizedBox(height: 16,),
            Text(
              "Disclaimer:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "While the application has been developed with thorough attention to accuracy and operational relevance, users are strongly advised to independently verify all data prior to official use. The developers assume no responsibility for errors or outcomes arising from its use. Users accept full responsibility for validation and adherence to applicable standards and procedures.",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              " Concept, Design & Technical Guidance: ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "Shri R Mahesh Kumar, Senior Manager (CNS), Airports Authority of India",
              style: TextStyle(fontSize: 16),
            ),
            SizedBox(height: 16),
            Text(
              " Support & Contributions ",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),              
            ),
            Text(
              "Appreciation is extended to the following individuals and teams for their valuable support:",
              style: TextStyle(fontSize: 16),              
            ),
            SizedBox(height: 8,),
            Text(
              "Shri M. Ravi Kumar, Senior Manager (CNS)\n"
              "Shri N. Prasad, Joint General Manager (CNS)\n"
              "NAV-AIDS Team, AAI, HIAL",
              style: TextStyle(fontSize: 16),               
            ),
            SizedBox(height: 16,),
            Text(
              "Developed by:",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              "U SAI LIKHITH,\nB.Tech, Department of Computer Science and Engineering\nIIT BOMBAY.",
              style: TextStyle(fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}


class LocalizerScreen extends StatelessWidget{
  @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Padding(padding:const EdgeInsets.symmetric(vertical: 8.0),
           ),
           SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>FirstDetailsPage("NPO RTS 734")),);
            },
             child: Text("NPO RTS 734",style: TextStyle(fontSize: 18),)),),
             SizedBox(height: 30),
             SizedBox(
              width: 250,
              child: 
             ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>NORpage("NORMARC 7014B")),);
            },
             child: Text("NORMARC 7014B",style: TextStyle(fontSize: 18),)),),
            //  SizedBox(height: 20,),
          ],
        ),
      ),
      ),
    ),
      ],
    ),
    );
  }
} 

class FirstDetailsPage extends StatelessWidget{
  final String blah;
  FirstDetailsPage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> KitDetailsPage("Kit-1")),);
            }, child: Text("Kit-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> KitDetailsPage("Kit-2")),);
            }, child: Text("Kit-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class KitDetailsPage extends StatefulWidget{
  final String kitname;
  KitDetailsPage(this.kitname);
  @override
  _kitdetailsPagestate createState() => _kitdetailsPagestate();
}

class _kitdetailsPagestate extends State <KitDetailsPage>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Centre Line/Position Adjustment",context),
            SizedBox(height: 16,),
            subButton("Course Width Adjustment",context),
            SizedBox(height: 16,),
            subButton("SDM/Mod Sum Adjustment",context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Position Alarm",context),
            SizedBox(height: 16,),
            subButton("Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Power Alarm", context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Centre Line/Position Adjustment':
            page = CentreLinePositionAdjustment(kitname :widget.kitname);
            break;
          case 'Course Width Adjustment':
            page = CourseWidthAdjustment(kitname :widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = ModulationLevelAdjustment(kitname :widget.kitname);
            break;
          case 'Position Alarm':
            page = PositionAlarm(kitname :widget.kitname);
            break;
          case 'Width Alarm':
            page = WidthAlarm(kitname :widget.kitname);
            break;
          case 'Power Alarm':
            page = PowerAlarm(kitname :widget.kitname);
            break;
          case 'Clearance Alarm':
            page = ClearanceAlarm(kitname : widget.kitname);
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}


class subpage extends StatelessWidget{
  final String title;
  subpage(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
       body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(

  
      appBar: AppBar(
        title: Text("$title Page"),
      ),
      body: Center(
        child: Text("Details will be updated soon",style: TextStyle(fontSize: 22),),
      ),
      
          
    ),)
      ] )  );
  }
}


class CentreLinePositionAdjustment extends StatefulWidget {
  final String kitname;
  CentreLinePositionAdjustment({required this.kitname});
  @override
  _CentreLinePositionAdjustmentState createState() => _CentreLinePositionAdjustmentState();
}

class _CentreLinePositionAdjustmentState extends State<CentreLinePositionAdjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y12Controller = TextEditingController();

  String x11Text = '';
  String x12Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  String outputMA = '';
  String outputPercent = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    y11Controller.addListener((){
    if(y11Controller.text.isNotEmpty){
      y12Controller.clear();
      setState(() {});
    }
    });
     y12Controller.addListener((){
    if(y12Controller.text.isNotEmpty){
      y11Controller.clear();
      setState(() {});
    }
    });
  }

  

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}CLPAx11') ?? '';
      x12Text = prefs.getString('${widget.kitname}CLPAx12') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}CLPAx11Fixed') ?? false;
      x12Fixed = prefs.getBool('${widget.kitname}CLPAx12Fixed') ?? false;
      x11Controller.text = x11Text;
      x12Controller.text = x12Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLPAx11', x11Text);
    prefs.setString('${widget.kitname}CLPAx12', x12Text);
    prefs.setBool('${widget.kitname}CLPAx11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}CLPAx12Fixed', x12Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Text);
    double? y11 = double.tryParse(y11Controller.text);
    double? y12 = double.tryParse(y12Controller.text);
    if(y11 != null){
      y12 = null;
    }
    else if(y12 != null){
      y11 = null;
    }
    if (x11 != null && x12 !=null && y11 != null) {
      outputMA = (x11 + y11).toStringAsFixed(3);
    } else if(x11!=null && y12 != null && x12 != null){
      outputMA = (x11 + ((x11*y12)/x12)).toStringAsFixed(3);
    }
    else{
      outputMA = '';
    }

    if ( x11!=null && x12 != null && y12 != null) {
      outputPercent = (x12 + y12).toStringAsFixed(3);
    } else if( x11 != null && x12 != null && y11!= null) {
      outputPercent = (((y11 * x12)/x11) + x12).toStringAsFixed(3);
    }
    else{
      outputPercent = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Centre Line/Position Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator DDM (in MKA)', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Existing NB Modulator DDM (in %)', x12Controller, x12Fixed, () {
              x12Fixed = !x12Fixed;
              x12Text = x12Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: y11Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
            TextField(
              controller: y12Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputMA.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Modular DDM (in MKA): $outputMA', style: TextStyle(fontSize: 18)),
              ),
            if (outputPercent.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Modular DDM (in %): $outputPercent', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Course line shifted 90 side: Adjust (- ) MKA as per FIU.\n 2.Course line shifted 150 side: Adjust (+ ) MKA as per FIU.',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),)
    )]));
  }
}

double log10(double x) => log(x) / ln10;

class CourseWidthAdjustment extends StatefulWidget {
  final String kitname;
  CourseWidthAdjustment({required this.kitname});
  @override
  _CourseWidthAdjustmentState createState() => _CourseWidthAdjustmentState();
}

class _CourseWidthAdjustmentState extends State<CourseWidthAdjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDBM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CWAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CWAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CWAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CWAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CWAx21', x21Text);
    prefs.setString('${widget.kitname}CWAx22', x22Text);
    prefs.setBool('${widget.kitname}CWAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CWAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDBM = (x22 + (20 * (log10(x23) - log10(x21)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDBM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Course Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required Course Width(in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB Modulator,PSB(in DBM)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Existing Course Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDBM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator PSB (in DBM): $outputDBM', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}



class ModulationLevelAdjustment extends StatefulWidget {
  final String kitname;
  ModulationLevelAdjustment({required this.kitname});
  @override
  _ModulationLevelAdjustmentState createState() => _ModulationLevelAdjustmentState();
}

class _ModulationLevelAdjustmentState extends State<ModulationLevelAdjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}MLAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}MLAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}MLAx31', x31Text);
    prefs.setBool('${widget.kitname}MLAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator SDM (in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator SDM (in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}


class PositionAlarm extends StatefulWidget {
  final String kitname;
  PositionAlarm({required this.kitname});
  @override
  _PositionAlarmState createState() => _PositionAlarmState();
}

class _PositionAlarmState extends State<PositionAlarm> {
  TextEditingController x41Controller = TextEditingController();
  TextEditingController x42Controller = TextEditingController();


  String x41Text = '';
  String x42Text = '';
  bool x41Fixed = false;
  String output90 = '';
  String output150 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x41Text = prefs.getString('${widget.kitname}POSALx41') ?? '';
      x41Fixed = prefs.getBool('${widget.kitname}POSALx41Fixed') ?? false;
      x41Controller.text = x41Text;
      x42Controller.text = x42Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}POSALx41', x41Text);
    prefs.setBool('${widget.kitname}POSALx41Fixed', x41Fixed);
  }

  void calculateOutput() {
    double? x41 = double.tryParse(x41Text);
    double? x42 = double.tryParse(x42Controller.text);


    if (x41 != null && x42 != null) {
      output90 = (x41 - x42).toStringAsFixed(3);
      output150 = (x41 + x42).toStringAsFixed(3);
    } else {
      output90 = '';
      output150 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Postion Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Updated NB Modulator DDM Value (in MKA)', x41Controller, x41Fixed, () {
              x41Fixed = !x41Fixed;
              x41Text = x41Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x42Controller,
              decoration: InputDecoration(
                labelText: 'Required amount of alarm (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output90.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator for 90Hz Side (in MKA): $output90', style: TextStyle(fontSize: 18)),
              ),
              if(output150.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB Modulator for 150Hz Side (in MKA):$output150',style: TextStyle(fontSize: 18),),
              ),
              SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Cat-3 --- 6 MKA \n 2.Cat-2 --- 11 MKA \n 3.Cat-1 --- 15 MKA',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}


class WidthAlarm extends StatefulWidget {
  final String kitname;
  WidthAlarm({required this.kitname});
  @override
  _WidthAlarmState createState() => _WidthAlarmState();
}

class _WidthAlarmState extends State<WidthAlarm> {
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}WAx51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}WAx51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}WAx51', x51Text);
    prefs.setBool('${widget.kitname}WAx51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (x51 + (20 * (log10(x51/(x51-(x51*x52/100)))))).toStringAsFixed(3);
      outputWide = (x51 + (20 * (log10(x51/(x51+(x51*x52/100)))))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('NB Modulator , PSB (in DBM)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(outputNarrow.isNotEmpty && outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('NB Modulator PSB (in DBS) :', style: TextStyle(fontSize: 18)),
              ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' Narrow Alarm: $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text(' Wide Alarm: $outputWide', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 17% \n 2. Cat-2/3 --- 10%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}


class PowerAlarm extends StatefulWidget {
  final String kitname;
  PowerAlarm({required this.kitname});
  @override
  _PowerAlarmState createState() => _PowerAlarmState();
}

class _PowerAlarmState extends State<PowerAlarm> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}PAx31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}PAx31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}PAx31', x31Text);
    prefs.setBool('${widget.kitname}PAx31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 - x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Power Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing NB Modulator PCSB (in DBM)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'For alarm , reduce power by (in DB)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Adjust NB Modulator PCSB  to (in DBM): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text("Note: \n 1. For single frequency EQPT : 3 DB \n 2. for dual frequency EQPT : 1 DB",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class ClearanceAlarm extends StatefulWidget{
  final String kitname;
  ClearanceAlarm({required this.kitname});
  @override
  _ClearanceAlarmState createState() => _ClearanceAlarmState();
}

class _ClearanceAlarmState extends State<ClearanceAlarm> {  
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDBM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CLAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CLAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CLAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CLAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLAx21', x21Text);
    prefs.setString('${widget.kitname}CLAx22', x22Text);
    prefs.setBool('${widget.kitname}CLAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CLAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDBM = (x21 + (20 * (log10(x22) - log10(x23)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDBM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Clearance Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing WB Modulator PSB (in DBM)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Minimum clearance current required (in MKA)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Measured clearance current as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDBM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New WB Modulator PSB (in DBM): $outputDBM', style: TextStyle(fontSize: 18)),
              ),
               SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note: \n Required minimum clearance current : 160 MKA',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class NPOScreen extends StatelessWidget{
  @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
             Padding(padding:const EdgeInsets.symmetric(vertical: 8.0),
           ),
           SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>SecondDetailsPage("NPO RTS 734")),);
            },
             child: Text("NPO RTS 734",style: TextStyle(fontSize: 18),)),),
             SizedBox(height: 30),
             SizedBox(
              width: 250,
              child: 
             ElevatedButton(onPressed: (){
              Navigator.push(context,
               MaterialPageRoute(builder:(context)=>NOR1page("NORMARC 7034B")),);
            },
             child: Text("NORMARC 7034B",style: TextStyle(fontSize: 18),)),),
            //  SizedBox(height: 20,),
          ],
        ),
      ),
      ),
    ),
      ],
    ),
    );
  }
} 

class SecondDetailsPage extends StatelessWidget{
  final String blah;
  SecondDetailsPage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GlidePathScreen("Kit-1")),);
            }, child: Text("Kit-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GlidePathScreen("Kit-2")),);
            }, child: Text("Kit-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class GlidePathScreen extends StatefulWidget{
  final String kitname;
  GlidePathScreen(this.kitname);
  @override
  _GlidePathScreenstate createState() => _GlidePathScreenstate();
}

class _GlidePathScreenstate extends State <GlidePathScreen>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text(" Glide Path ${widget.kitname}"),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Glide Angle Adjustment",context),
            SizedBox(height: 16,),
            subButton("Sector Width Adjustment",context),
            SizedBox(height: 16.0,),
            subButton("SDM/Mod Sum Adjustment", context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Sector Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Glide Angle Alarm",context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }
  Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Glide Angle Adjustment':
            page = GlideAngleAdjustment(kitname:widget.kitname);
            break;
          case 'Sector Width Adjustment':
            page = SectorWidthAdjustment(kitname:widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = SDMModAjustment();
          case 'Sector Width Alarm':
            page = SectorWidthAlarm(kitname:widget.kitname);
          case 'Glide Angle Alarm':
            page = GlideAngleAlarm(kitname:widget.kitname);
            break;
          case 'Clearance Alarm' :
            page = CLAlarm();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class GlideAngleAdjustment extends StatefulWidget {
  final String kitname;
  GlideAngleAdjustment({required this.kitname});
  @override
  _GlideAngleAdjustmentState createState() => _GlideAngleAdjustmentState();
}

class _GlideAngleAdjustmentState extends State<GlideAngleAdjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController x13Controller = TextEditingController();
  TextEditingController x14Controller = TextEditingController();
  TextEditingController x15Controller = TextEditingController();


  String x11Text = '';
  String x12Text = '';
  String x13Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  bool x13Fixed = false;
  String outputperc = '';
  String outputMKA = '';
  String output3 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    x14Controller.addListener((){
      if(x14Controller.text.isNotEmpty){
        x15Controller.clear();
        setState(() { });
      }
    });
    x15Controller.addListener((){
      if(x15Controller.text.isNotEmpty){
        x14Controller.clear();
        setState(() { });
      }
    });
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}GAAx11') ?? '';
      x12Text = prefs.getString('${widget.kitname}GAAx12') ?? '';
      x13Text = prefs.getString('${widget.kitname}GAAx13') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}GAAx11Fixed') ?? false;
      x12Fixed = prefs.getBool('${widget.kitname}GAAx12Fixed') ?? false;
      x13Fixed = prefs.getBool('${widget.kitname}GAAx13Fixed') ?? false;
      x11Controller.text = x11Text;
      x12Controller.text = x12Text;
      x13Controller.text = x13Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAAx11', x11Text);
    prefs.setString('${widget.kitname}GAAx12', x12Text);
    prefs.setString('${widget.kitname}GAAx13', x13Text);
    prefs.setBool('${widget.kitname}GAAx11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}GAAx12Fixed', x12Fixed);
    prefs.setBool('${widget.kitname}GAAx13Fixed', x13Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Text);
    double? x13 = double.tryParse(x13Text);
    double? x14 = double.tryParse(x14Controller.text);
    double? x15 = double.tryParse(x15Controller.text);


    if (x11 != null && x13 != null && x12!= null && x14!= null) {
      outputperc = (((x11 - x14)*8.75/0.36)+ x12 ).toStringAsFixed(3);
      outputMKA = (((x11 - x14)*75/0.36)+ x13 ).toStringAsFixed(3);
      output3 = '';
      // outputDBM = result.toStringAsFixed(3);
    } else if(x11 != null && x13 != null && x12!= null && x15 !=null){
      output3 = (x13 + x15).toStringAsFixed(3);
      outputperc = '';
      outputMKA = '';
    }
    else {
      outputperc = '';
      outputMKA = '';
      output3 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required Glide Angle(in Deg)', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 1 (in %)', x12Controller, x12Fixed, () {
              x12Fixed = !x12Fixed;
              x12Text = x12Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
             inputField('NB DDM of Antenna 1 (in MKA)', x13Controller, x13Fixed, () {
              x13Fixed = !x13Fixed;
              x13Text = x13Controller.text;
              saveValues();
            }),
            SizedBox(height: 16,),
            TextField(
              controller: x14Controller,
              decoration: InputDecoration(
                labelText: ' Measured Glide Angle as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
             SizedBox(height: 16,),
            TextField(
              controller: x15Controller,
              decoration: InputDecoration(
                labelText: ' Adjust Glide Angle as per FIU (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputperc.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in %) : $outputperc', style: TextStyle(fontSize: 18)),
              ),
            if (outputMKA.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) : $outputMKA', style: TextStyle(fontSize: 18)),
              ),
            if (output3.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text("New NB DDM of Antenna 1 (in MKA) : $output3",style: TextStyle(fontSize: 18 ),),)
          ],
        ),
      ),
      ))]));
  }
}

class SectorWidthAdjustment extends StatefulWidget {
  final String kitname;
  SectorWidthAdjustment({required this.kitname});
  @override
  _SectorWidthAdjustmentState createState() => _SectorWidthAdjustmentState();
}

class _SectorWidthAdjustmentState extends State<SectorWidthAdjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output2 = '';
  String output1 = '';
  String output3 = '';


  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWAx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWAx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWAx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWAx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWAx21', x21Text);
    prefs.setString('${widget.kitname}SWAx22', x22Text);
    prefs.setBool('${widget.kitname}SWAx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWAx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      output2 = ((x22 * x23)/x21).toStringAsFixed(3);
      output1 = (((x22 * x23)/x21)/4).toStringAsFixed(3);
      double output = (((x22 * x23)/x21)/800);
      output3 = output.abs().toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output2 = '';
      output1 = '';
      output3 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required HSW (UHSW+LHSW = 0.24θ) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 2  (in %)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Measured Half Sector Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output1.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 1: $output1', style: TextStyle(fontSize: 18)),
              ),
            if (output2.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 2: $output2', style: TextStyle(fontSize: 18)),
              ),
            if (output3.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Antenna 3: NB Level 90 Hz is $output3 \n              NB Level 150 Hz is -$output3', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SDMModAjustment extends StatelessWidget{
   @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("SDM/Mod Sum Adjustment"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children:[ Text("Adjust the NB DDM (%) of Antenna A1 & A2 simultaneously in the modulator setting as per FIU and verify it in the monitor window. ",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
      ]) ,
      ))]));
}
}

class SectorWidthAlarm extends StatefulWidget {
  final String kitname;
  SectorWidthAlarm({required this.kitname});
  @override
  _SectorWidthAlarmState createState() => _SectorWidthAlarmState();
}

class _SectorWidthAlarmState extends State<SectorWidthAlarm> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output2 = '';
  String output1 = '';
  String output3 = '';
  String output4 = '';
  String output5 = '';
  String output6 = '';
  String output7 = '';
  String output8 = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWALx21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWALx22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWALx21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWALx22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWALx21', x21Text);
    prefs.setString('${widget.kitname}SWALx22', x22Text);
    prefs.setBool('${widget.kitname}SWALx21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWALx22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      double blah1 = (x21 + (x21*x23/100));
      output1 = blah1.toStringAsFixed(3);
      double blah2 = (x21 - (x21*x23/100));
      output2 = blah2.toStringAsFixed(3);
      double blah3 = ((x21* x22)/blah1);
      output3 = blah3.toStringAsFixed(3);
      double blah4 = ((x21* x22)/blah2);
      output4 = blah4.toStringAsFixed(3);
      double blah5 = (blah3)/4;
      output5 = blah5.toStringAsFixed(3);
      double blah6 = (blah4)/4;
      output6 = blah6.toStringAsFixed(3);
      output7 = ((blah3.abs())/800).toStringAsFixed(3);
      output8 = ((blah4.abs())/800).toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output2 = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Measured HSW as per the FIU (LHSW+UHSW) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('NB DDM of Antenna 2 (in %)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Required % of alarm ',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if(output1.isNotEmpty && output2.isNotEmpty)
              Padding(padding: const EdgeInsets.only(top: 16),
              child: Table(
                border: TableBorder.all(color: Colors.black),
                children: [
                  TableRow(
                    children: [
                    Text('Paramters',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('Wide Alarm',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('Narrow Alarm',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Width DDM (in Deg)',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output1',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output2',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('NB DDM of Antenna 2 (in %)',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output3',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output4',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('NB DDM of Antenna 1 (in %)',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output5',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output6',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 3 NB Level 90 Hz',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output7',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('$output8',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  ),
                  TableRow(
                    children: [
                    Text('Antenna 3 NB Level 90 Hz',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('-$output7',style: TextStyle(fontWeight: FontWeight.bold),),
                    Text('-$output8',style: TextStyle(fontWeight: FontWeight.bold),),
                    ]
                  )
                ],
              ),),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 25% \n 2. Cat-2/3 --- 20%",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class GlideAngleAlarm extends StatefulWidget {
  final String kitname;
  GlideAngleAlarm({required this.kitname});
  @override
  _GlideAngleAlarmState createState() => _GlideAngleAlarmState();
}

class _GlideAngleAlarmState extends State<GlideAngleAlarm> {
  TextEditingController x51Controller = TextEditingController();
  TextEditingController x52Controller = TextEditingController();


  String x51Text = '';
  bool x51Fixed = false;
  String outputNarrow = '';
  String outputWide = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x51Text = prefs.getString('${widget.kitname}GAALx51') ?? '';
      x51Fixed = prefs.getBool('${widget.kitname}GAALx51Fixed') ?? false;
      x51Controller.text = x51Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAALx51', x51Text);
    prefs.setBool('${widget.kitname}GAALx51Fixed', x51Fixed);
  }

  void calculateOutput() {
    double? x51 = double.tryParse(x51Text);
    double? x52 = double.tryParse(x52Controller.text);


    if (x51 != null && x52 != null) {
      outputNarrow = (x51 + x52).toStringAsFixed(3);
      outputWide = (x51 - x52).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputNarrow = '';
      outputWide = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Alarm')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('NB DDM of Antenna 1 (in MKA)', x51Controller, x51Fixed, () {
              x51Fixed = !x51Fixed;
              x51Text = x51Controller.text;
              saveValues();
            }),
            
            SizedBox(height: 8),
            TextField(
              controller: x52Controller,
              decoration: InputDecoration(
                labelText: 'Amount of alarm required (in MKA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputNarrow.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) for upper side alarm : $outputNarrow', style: TextStyle(fontSize: 18)),
              ),
            if (outputWide.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM of Antenna 1 (in MKA) for lower side alarm : $outputWide', style: TextStyle(fontSize: 18)),
              ),
              SizedBox(height: 30,),
              Padding(padding: EdgeInsets.only(top: 10),
              child: Text(" Note: \n 1. Cat-1 --- 45 MKA \n 2. Cat-2 --- 35 MKA \n 3. Cat-3 --- 26 MKA",style: TextStyle(color: Colors.red),),)
          ],
        ),
      ),
      ))]));
  }
}

class CLAlarm extends StatelessWidget{
   @override
  Widget build(context){
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(24.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              crossAxisAlignment: CrossAxisAlignment.end,
              verticalDirection: VerticalDirection.up,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
    Expanded(
      child: Scaffold(
      appBar: AppBar(
        title: Text("Clearance Alarm"),
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children:[ Text("Reduce the WB level in Antenna-1 and Antenna-3 simulateneously to achieve a minimum current of 190 \u03BCA (WB DDM , MKA) below glide angle. ",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 18),),
      ]) ,
      ))]));
}
}

class GeneralScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          SizedBox(
          width: 250,
          child:  ElevatedButton(
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => CalibrationDetailScreen("Conversions")));
            },
            child: Text("Conversions",style: TextStyle(fontSize: 18),),
          )),
          SizedBox(height: 30,),
          SizedBox(
          width: 250,
          child:  ElevatedButton(
            onPressed: (){
              Navigator.push(context, MaterialPageRoute(builder: (context) => GeneralInfo()));
            },
            child: Text("General Info",style: TextStyle(fontSize: 18),),
          )),
        ],
      ),
    );
  }
}

class GeneralInfo extends StatelessWidget { 
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text('General Info'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('ICAO ANNEXES AND THEIR VOLUMES:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('''
ICAO Annex 1 – Personnel Licensing: Covers pilot, air traffic controller, and engineer licensing requirements.
ICAO Annex 2 – Rules of the Air: Establishes flight rules, right-of-way rules, and operational procedures.
ICAO Annex 3 – Meteorological Service for Air Navigation:
  Vol I: Core meteorological standards
  Vol II: Technical specifications for meteorological services
ICAO Annex 4 – Aeronautical Charts: Covers standards for airport and en-route charts.
ICAO Annex 5 – Units of Measurement to Be Used in Air and Ground Operations: Specifies measurement units for altitude, speed, and distance.
ICAO Annex 6 – Operation of Aircraft: 
  Vol I: Commercial air transport operations
  Vol II: General aviation operations
  Vol III: Helicopter operations
ICAO Annex 7 – Aircraft Nationality and Registration Marks: Defines aircraft registration requirements.
ICAO Annex 8 – Airworthiness of Aircraft: Specifies aircraft safety, maintenance, and certification standards.
ICAO Annex 9 – Facilitation: Covers border control, customs, and immigration procedures.
ICAO Annex 10 – Aeronautical Telecommunications
  Vol I: Radio Navigation Aids (Includes ILS, VOR, and DME)
  Vol II: Communication procedures
  Vol III: Voice communication systems
  Vol IV: Surveillance systems (Radar, ADS-B)
  Vol V: Data communication systems
ICAO Annex 11 – Air Traffic Services (ATS): Defines airspace management, ATC procedures, and flight separation.
ICAO Annex 12 – Search and Rescue (SAR): Covers SAR planning, coordination, and emergency response.
ICAO Annex 13 – Aircraft Accident and Incident Investigation: Specifies investigation procedures and reporting standards.
ICAO Annex 14 – Aerodromes:
  Vol I: Aerodrome Design and Operations
  Vol II: Heliports
ICAO Annex 15 – Aeronautical Information Services: Covers NOTAMs, AIP, and flight information publication standards.
ICAO Annex 16 – Environmental Protection
  Vol I: Aircraft noise standards
  Vol II: Aircraft engine emissions
ICAO Annex 17 – Security: Covers aviation security, anti-terrorism, and passenger screening.
ICAO Annex 18 – The Safe Transport of Dangerous Goods by Air: Defines regulations for hazardous materials transport.
ICAO Annex 19 – Safety Management: Covers Safety Management Systems (SMS) and risk mitigation.
'''),
              SizedBox(height: 20),

              Text('CATEGORIES OF ILS:', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Text('''The Category of Instrument Landing Systems (ILS) lies in the minimum visibility and decision heights they allow for pilots to safely land during poor weather conditions. 

These categories are defined based on the precision of the system and the level of automation in the aircraft.'''),
              SizedBox(height: 20),

              Text('Reference Datum',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
              SizedBox(height: 10,),

              Text('''•	The Reference Datum is the point at which the standard glide slope intersects the runway threshold plane.
•	It is used to establish the correct descent path for landing.'''),
            SizedBox(height: 10,),
            Text('Significance:',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''•	Ensures precision approaches are correctly aligned with the runway.
•	Helps pilots maintain a stable approach profile.
•	Used for calculating Minimum Descent Altitude (MDA) and Decision Height (DH).'''),
            SizedBox(height: 20,),
            Text('Decision Height (DH)',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''Decision Height (DH) is the altitude above the runway threshold at which the pilot must decide to either:
1.	Continue the approach and land (if the runway is visible and conditions allow).
2.	Execute a missed approach (if the runway is not visible).
•	Used in CAT I, II, and III precision approaches (e.g., ILS).
'''),
            SizedBox(height: 10,),
             Text('Significance:',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold)),
            SizedBox(height: 10,),
            Text('''•	Ensures pilots do not descend below safe altitudes without sufficient visual references.
•	Critical for low-visibility landings in CAT II/III ILS approaches.
•	Helps avoid Controlled Flight Into Terrain (CFIT).
'''),

              Text('ILS Comparison Chart:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),

              Table(
                border: TableBorder.all(),
                columnWidths: {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1),
                  4: FlexColumnWidth(1),
                  5: FlexColumnWidth(1),
                  6: FlexColumnWidth(1),
                },
                children: [
                  TableRow(children: [
                    Text('ILS Category', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Decision Height (DH)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Runway Visibility (RVR)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Ground Requirements', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Onboard Requirements', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Localizer Accuracy', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Glide Slope Accuracy', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  TableRow(children: [
                    Text('CAT I'), Text('200 ft'), Text('550 m'), Text('Basic ILS, ALS'), Text('Basic ILS receiver, manual control'), Text('±10.5 m'), Text('±0.075°')
                  ]),
                  TableRow(children: [
                    Text('CAT II'), Text('100 ft'), Text('300 m'), Text('Enhanced ILS, ALS, RVR sensors'), Text('Autopilot, radar altimeter, training'), Text('±7.5 m'), Text('±0.05°')
                  ]),
                  TableRow(children: [
                    Text('CAT III A'), Text('50 ft'), Text('200 m'), Text('Precise ILS, lighting, RVR sensors'), Text('Autoland, fail-passive systems'), Text('±3.5 m'), Text('±0.03°')
                  ]),
                  TableRow(children: [
                    Text('CAT III B'), Text('<50 ft'), Text('50-175 m'), Text('Very precise ILS, advanced lighting'), Text('Autoland, fail-operational systems'), Text('±1.5 m'), Text('±0.02°')
                  ]),
                  TableRow(children: [
                    Text('CAT III C'), Text('No Limit'), Text('No Limit'), Text('Full precision, no RVR limits'), Text('Full automation, high redundancy'), Text('±1.0 m'), Text('±0.01°')
                  ]),
                ],
              ),
              SizedBox(height: 20),

              Text('Distance vs. DH table for a 3° glide slope:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 10),
              Text('''RDH is the height where the aircraft intersects the ILS glide path above the runway threshold.'''),
              SizedBox(height: 10,),
              Table(
                border: TableBorder.all(),
                children: [
                  TableRow(children: [
                    Text('Distance (NM)', style: TextStyle(fontWeight: FontWeight.bold)),
                    Text('Altitude Above Threshold (ft)', style: TextStyle(fontWeight: FontWeight.bold)),
                  ]),
                  TableRow(children: [
                    Text('10 NM'), Text('3,000 ft')
                  ]),
                  TableRow(children: [
                    Text('5 NM'), Text('1,500 ft')
                  ]),
                  TableRow(children: [
                    Text('3 NM'), Text('900 ft')
                  ]),
                  TableRow(children: [
                    Text('2 NM'), Text('600 ft')
                  ]),
                  TableRow(children: [
                    Text('1 NM'), Text('300 ft')
                  ]),
                  TableRow(children: [
                    Text('Threshold'), Text('50 ft (RDH)')
                  ]),
                ],
              ),
              SizedBox(height: 20,),
              Text('Localizer (LLZ) – Lateral Guidance',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
              SizedBox(height: 10,),
              Text('''•	Localizer (LLZ): 108.10 – 111.95 MHz (VHF band, 25 kHz spacing)
•	Coverage:
    o	±35° from the centerline for 10 NM.
    o	±10° from the centerline for 25 NM.
•	Modulation Frequencies:
    o	90 Hz (Left of Centerline)
    o	150 Hz (Right of Centerline)
•	Course Width: 3° – 6° (typically set to give a full-scale deflection of ±150 µA at 2.5°).
•	Accuracy: ±10.5 m (35 ft) at threshold.
'''),
            SizedBox(height: 20,),
            Text('Glide Path (GP) – Vertical Guidance',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
            SizedBox(height: 10,),
            Text('''•	Glide Path (GP): 329.15 – 335.00 MHz (UHF band, 150 kHz spacing)
•	Coverage:
    o	8° beamwidth (vertically)
    o	The vertical coverage is typically between 0.7° to 1.75° above and below the glide path.
    o	Coverage up to 10 NM from threshold.
•	Standard Glide Slope Angles: 2.5° – 3.5° (typically 3°).
•	Modulation Frequencies:
    o	90 Hz (Below Path)
    o	150 Hz (Above Path)
•	Glide Slope Deviation Sensitivity:
    o	0.35° full-scale deflection (typical).
'''),
          SizedBox(height: 20,),
          Text('ILS Signal Accuracy & Protection Limits',style: TextStyle(fontSize: 20,fontWeight: FontWeight.bold),),
          SizedBox(height: 20,),
          Text('Localizer ',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
          SizedBox(height: 10,),
          Text('''
    Alignment Error: ≤ 10% of course width.
    Displacement Sensitivity: 0.5° per 50 µA deflection on instruments.
    Course Stability: ±17 µA per second deviation allowed
'''),
          SizedBox(height: 20,),
          Text('Glide Path ',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
          SizedBox(height: 10,),
          Text('''
    Alignment Error: ≤ 0.075° (CAT I) / 0.02° (CAT III).
    Vertical Sensitivity: 0.35° full-scale deflection
    Course Stability: ±17 µA (micro watts) per second deviation allowed.
    Interference Protection: ICAO requires separation of at least 10 kHz between two 	localizer frequencies at nearby airports.
''')
            ],
          ),
        ),
      ),
      ))]));
  }
}

class PhasingScreen extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [SizedBox( width: 250,
         child: ElevatedButton(
          child: Text('NPO RTS 734 Localizer',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => PhasingLocalizer("NPO RTS 734 Localizer")));
        },),),
        SizedBox(height: 30,),
        SizedBox( 
          width: 250,
        child:ElevatedButton(child: Text('NPO RTS 734 Glide Path',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => PhasingGlidePath("NPO RTS 734 Glide Path")));
        },),),
        SizedBox(height: 30,),
        SizedBox( width: 250,
        child:ElevatedButton(child: Text('MOPIENS DVOR 220',style: TextStyle(fontSize: 18),),
        onPressed: (){
          Navigator.push(context, MaterialPageRoute(builder: (context) => subpage("MOPIENS DVOR 220 ")));
        },),),
        ]
      ),
    );
  }
}

class NORpage extends StatelessWidget{
  final String blah;
  NORpage(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Localizer"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GInfo()),);
            }, child: Text("General Information",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit1DetailsPage("Transmitter-1")),);
            }, child: Text("Transmitter-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit1DetailsPage("Transmitter-2")),);
            }, child: Text("Transmitter-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class NOR1page extends StatelessWidget{
  final String blah;
  NOR1page(this.blah);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              //  crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("$blah Glide Path"),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> GInfo()),);
            }, child: Text("General Information",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
            width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit2DetailsPage("Transmitter-1")),);
            }, child: Text("Transmitter-1",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,),
            SizedBox(
              width: 250,
            child: 
            ElevatedButton(onPressed: (){
              Navigator.push(context,
              MaterialPageRoute(builder: (context)=> Kit2DetailsPage("Transmitter-2")),);
            }, child: Text("Transmitter-2",style: TextStyle(fontSize: 18),)),),
            SizedBox(height: 20,width: 250,),
          ],
        ),
      ),
    ),
    ),
      ],
    )
    );
  }
}

class GInfo extends StatelessWidget{
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
        Expanded(child: Scaffold(
          appBar: AppBar(
            title: Text("General Information"),
          ),
          body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
          child:Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('''Preparation for flight calibration: ''',style: TextStyle(fontSize: 18,fontWeight: FontWeight.bold),),
              Text('''
1. On the equipment set the Local/Remote switch to Local and the Auto/Manual to Manual Position.
2. Set the write access key to a horizontal position, to enable the Login Level 3.
3. On the RMM login with level 3 as per station authentication (user and password).
4. In the Menu, go to File, and then Preferences and select the micro amps as the unit for DDM values
''',style: TextStyle(fontSize: 18),),
            ],
          ),)
        ))])
    );
  }
}

class Kit1DetailsPage extends StatefulWidget{
  final String kitname;
  Kit1DetailsPage(this.kitname);
  @override
  _kit1detailsPagestate createState() => _kit1detailsPagestate();
}

class _kit1detailsPagestate extends State <Kit1DetailsPage>{
   bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text("Localizer ${widget.kitname} "),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            sub1Button("Centre Line/Position Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Course Width Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("SDM/Mod Sum Adjustment",context),
            SizedBox(height: 16,),
            sub1Button("Coverage Check", context),
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            sub1Button("Position Alarm",context),
            SizedBox(height: 16,),
            sub1Button("Width Alarm",context),
            SizedBox(height: 16,),
            sub1Button("Power Alarm", context),
            SizedBox(height: 16,),
            sub1Button("Clearance Alarm", context),
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }

 Widget sub1Button(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Centre Line/Position Adjustment':
            page = CentreLinePosition1Adjustment(kitname :widget.kitname);
            break;
          case 'Course Width Adjustment':
            page = CourseWidth1Adjustment(kitname :widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = ModulationLevel1Adjustment(kitname :widget.kitname);
            break;
          case 'Coverage Check':
            page = CoverageCheck();
            break;
          case 'Position Alarm':
            page = PositionAlarm1();
            break;
          case 'Width Alarm':
            page = WidthAlarm1();
            break;
          case 'Power Alarm':
            page = PowerAlarm1();
            break;
          case 'Clearance Alarm':
            page = ClearanceAlarm1();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class Kit2DetailsPage extends StatefulWidget{
  final String kitname;
  Kit2DetailsPage(this.kitname);
  @override
  _kit2detailsPagestate createState() => _kit2detailsPagestate();
}

class _kit2detailsPagestate extends State <Kit2DetailsPage>{
  bool showAdj_subbuttons = false;
   bool showAlrm_subbuttons = false;
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(
        title: Text(" Glide Path ${widget.kitname}"),
      ),
      body: Center(
       child:Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 400,
            child: 
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.orangeAccent : Colors.deepPurple,
              ),
              foregroundColor: MaterialStateProperty.all(
                showAdj_subbuttons ? Colors.white : Colors.white
              )
              
            ),
            onPressed: (){
            setState(() {
              showAdj_subbuttons = !showAdj_subbuttons;
              showAlrm_subbuttons = false;
            });
          }, child: Text("Calibration Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAdj_subbuttons)...[
            SizedBox(height: 30,),
            subButton("Glide Angle Adjustment",context),
            SizedBox(height: 16,),
            subButton("Sector Width Adjustment",context),
            SizedBox(height: 16.0,),
            subButton("SDM/Mod Sum Adjustment", context),
            SizedBox(height: 16.0,),
            subButton("Coverage Check", context)
          ],
          SizedBox(height: 30,width: 250,),
          SizedBox(
            width: 400,
            child: 
           ElevatedButton(
           style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.orange : Colors.deepPurple,
              ),
              foregroundColor:  MaterialStateProperty.all(
                showAlrm_subbuttons ? Colors.white : Colors.white,
              ),
           ),
            onPressed: (){
            setState(() {
              showAlrm_subbuttons = !showAlrm_subbuttons;
              showAdj_subbuttons = false;
            });
          }, child: Text("Alarm Adjustments",style: TextStyle(fontSize: 18),)),),
          if(showAlrm_subbuttons)...[
            SizedBox(height: 30,width: 160,),
            subButton("Position Alarm",context),
            SizedBox(height: 16,),
            subButton("Width Alarm",context),
            SizedBox(height: 16,),
            subButton("Power Alarm", context),
            SizedBox(height: 16,),
            subButton("Clearance Alarm", context), 
          ],
          SizedBox(height: 20,),
        ],
      ),
      ),
      )
      ),
      ]
      )
    );
  }
  Widget subButton(String title, BuildContext context) {
  return SizedBox(
    width: 300,
    child: ElevatedButton(
      onPressed: () {
        Widget page;
        switch (title) {
          case 'Glide Angle Adjustment':
            page = GlideAngle1Adjustment(kitname:widget.kitname);
            break;
          case 'Sector Width Adjustment':
            page = SectorWidth1Adjustment(kitname:widget.kitname);
            break;
          case 'SDM/Mod Sum Adjustment':
            page = SDMMod1Ajustment(kitname:widget.kitname);
          case 'Coverage Check':
            page = CoverageCheck();
            break;
          case 'Position Alarm':
            page = PositionAlarm1();
          case 'Width Alarm':
            page = WidthAlarm1();
            break;
          case 'Power Alarm':
            page = PowerAlarm1();
            break;
          case 'Clearance Alarm' :
            page = ClearanceAlarm1();
          default:
            page = Scaffold(body: Center(child: Text("Page Not Found")));
        }
        
        Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => page),
        );
      },
      child: Text(title, style: TextStyle(fontSize: 16)),
    ),
  );
}
}

class CentreLinePosition1Adjustment extends StatefulWidget {
  final String kitname;
  CentreLinePosition1Adjustment({required this.kitname});
  @override
  _centreLinePositionAdjustmentState createState() => _centreLinePositionAdjustmentState();
}

class _centreLinePositionAdjustmentState extends State<CentreLinePosition1Adjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController y11Controller = TextEditingController();
  TextEditingController y12Controller = TextEditingController();

  String x11Text = '';
  String x12Text = '';
  bool x11Fixed = false;
  bool x12Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    y11Controller.addListener((){
    if(y11Controller.text.isNotEmpty){
      y12Controller.clear();
      setState(() {});
    }
    });
     y12Controller.addListener((){
    if(y12Controller.text.isNotEmpty){
      y11Controller.clear();
      setState(() {});
    }
    });
  }

  

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}CLPA1x11') ?? '';
      // x12Text = prefs.getString('${widget.kitname}CLPA1x12') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}CLPA1x11Fixed') ?? false;
      // x12Fixed = prefs.getBool('${widget.kitname}CLPA1x12Fixed') ?? false;
      x11Controller.text = x11Text;
      // x12Controller.text = x12Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CLPA1x11', x11Text);
    prefs.setString('${widget.kitname}CLPA1x12', x12Text);
    prefs.setBool('${widget.kitname}CLPA1x11Fixed', x11Fixed);
    prefs.setBool('${widget.kitname}CLPA1x12Fixed', x12Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    // double? x12 = double.tryParse(x12Text);
    double? y11 = double.tryParse(y11Controller.text);
    // double? y12 = double.tryParse(y12Controller.text);
   
    if (x11 != null && y11 !=null ) {
      output = (x11 + (y11/10)).toStringAsFixed(3);}
    else{
      output = '';
    }

    // if ( x11!=null && x12 != null && y12 != null) {
    //   outputPercent = (x12 + y12).toStringAsFixed(3);
    // } else if( x11 != null && x12 != null && y11!= null) {
    //   outputPercent = (((y11 * x12)/x11) + x12).toStringAsFixed(3);
    // }
    // else{
    //   outputPercent = '';
    // }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Centre Line/Position Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment DDM', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            // SizedBox(height: 8),
            // inputField(' DDM Adjustment required as per FIU(in \muA)', x12Controller, x12Fixed, () {
            //   x12Fixed = !x12Fixed;
            //   x12Text = x12Controller.text;
            //   saveValues();
            // }),
            SizedBox(height: 8),
            TextField(
              controller: y11Controller,
              decoration: InputDecoration(
                labelText: 'DDM Adjustment required as per FIU (in µA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            // SizedBox(height: 8),
            // TextField(
            //   controller: y12Controller,
            //   decoration: InputDecoration(
            //     labelText: 'DDM Adjustment required as per FIU (in %)',
            //     border: OutlineInputBorder(),
            //     contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            //   ),
            //   keyboardType: TextInputType.number,
            // ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment DDM (in µA): $output', style: TextStyle(fontSize: 18)),
              ),
            // if (outputPercent.isNotEmpty)
            //   Padding(
            //     padding: const EdgeInsets.only(top: 16.0),
            //     child: Text('New Modular DDM (in %): $outputPercent', style: TextStyle(fontSize: 18)),
            //   ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:\n 1.Course line shifted 90 side: Adjust (- ) µA as per FIU.\n 2.Course line shifted 150 side: Adjust (+ ) µA as per FIU.',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),)
    )]));
  }
}


class CourseWidth1Adjustment extends StatefulWidget {
  final String kitname;
  CourseWidth1Adjustment({required this.kitname});
  @override
  _courseWidthAdjustmentState createState() => _courseWidthAdjustmentState();
}

class _courseWidthAdjustmentState extends State<CourseWidth1Adjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String outputDB = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}CWA1x21') ?? '';
      x22Text = prefs.getString('${widget.kitname}CWA1x22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}CWA1x21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}CWA1x22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}CWA1x21', x21Text);
    prefs.setString('${widget.kitname}CWA1x22', x22Text);
    prefs.setBool('${widget.kitname}CWA1x21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}CWA1x22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      outputDB = (x21 + (20 * (log10(x23) - log10(x22)))).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else {
      outputDB = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Course Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing COU SBO level(in dB)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Required Course Width(in Deg)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Existing Course Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputDB.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New COU SB level (in dB): $outputDB', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class ModulationLevel1Adjustment extends StatefulWidget {
  final String kitname;
  ModulationLevel1Adjustment({required this.kitname});
  @override
  _modulationLevelAdjustmentState createState() => _modulationLevelAdjustmentState();
}

class _modulationLevelAdjustmentState extends State<ModulationLevel1Adjustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}MLA1x31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}MLA1x31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}MLA1x31', x31Text);
    prefs.setBool('${widget.kitname}MLA1x31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment SDM (in %)', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment SDM (in %): $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class CoverageCheck extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
          Expanded(child: Scaffold(
            appBar: AppBar(title: Text("Coverage Check"),),
            body: Padding(padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child:Column(
              crossAxisAlignment: CrossAxisAlignment.start,
            // padding: const EdgeInsets.symmetric(vertical: 16.0,horizontal: 4.0),
            children:[ Text('''
For Coverage Check :  ''',style: TextStyle(fontSize: 18,color: Colors.red)),
            Text('''
Go to ILS Setting Menu -> Transmitter Settings -> Signal Adjustment
1. Adjust COU RF for Cource Coverage
2. Adjust CLR RF for Clearance Coverage
            ''',style: TextStyle(fontSize: 18),)
          ]
          ),)
          ))]));
}
}

class GlideAngle1Adjustment extends StatefulWidget {
  final String kitname;
  GlideAngle1Adjustment({required this.kitname});
  @override
  _glideAngleAdjustmentState createState() => _glideAngleAdjustmentState();
}

class _glideAngleAdjustmentState extends State<GlideAngle1Adjustment> {
  TextEditingController x11Controller = TextEditingController();
  TextEditingController x12Controller = TextEditingController();
  TextEditingController x13Controller = TextEditingController();


  String x11Text = '';
  bool x11Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
    x12Controller.addListener((){
      if(x12Controller.text.isNotEmpty){
        x13Controller.clear();
        setState(() { });
      }
    });
    x13Controller.addListener((){
      if(x13Controller.text.isNotEmpty){
        x12Controller.clear();
        setState(() { });
      }
    });
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x11Text = prefs.getString('${widget.kitname}GAA1x11') ?? '';
      x11Fixed = prefs.getBool('${widget.kitname}GAA1x11Fixed') ?? false;
      x11Controller.text = x11Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}GAA1x11', x11Text);
    prefs.setBool('${widget.kitname}GAA1x11Fixed', x11Fixed);
  }

  void calculateOutput() {
    double? x11 = double.tryParse(x11Text);
    double? x12 = double.tryParse(x12Controller.text);
    double? x13 = double.tryParse(x13Controller.text);


    if (x11 != null && x12!= null) {
      output = (x11 + (x12/10) ).toStringAsFixed(3);
      // outputDBM = result.toStringAsFixed(3);
    } else if(x11 != null && x13 !=null){
      output = ((x13*20) + x11).toStringAsFixed(3);
    }
    else {
      output = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Glide Angle Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment DDM ', x11Controller, x11Fixed, () {
              x11Fixed = !x11Fixed;
              x11Text = x11Controller.text;
              saveValues();
            }),
            SizedBox(height: 16,),
            TextField(
              controller: x12Controller,
              decoration: InputDecoration(
                labelText: ' DDM Adjustment required as per FIU (in µA)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
             SizedBox(height: 16,),
            TextField(
              controller: x13Controller,
              decoration: InputDecoration(
                labelText: 'Glide Angle adjustment as per FIU (in deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New NB DDM (in µA) : $output', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SectorWidth1Adjustment extends StatefulWidget {
  final String kitname;
  SectorWidth1Adjustment({required this.kitname});
  @override
  _sectorWidthAdjustmentState createState() => _sectorWidthAdjustmentState();
}

class _sectorWidthAdjustmentState extends State<SectorWidth1Adjustment> {
  TextEditingController x21Controller = TextEditingController();
  TextEditingController x22Controller = TextEditingController();
  TextEditingController x23Controller = TextEditingController();


  String x21Text = '';
  String x22Text = '';
  bool x21Fixed = false;
  bool x22Fixed = false;
  String output = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x21Text = prefs.getString('${widget.kitname}SWA1x21') ?? '';
      x22Text = prefs.getString('${widget.kitname}SWA1x22') ?? '';
      x21Fixed = prefs.getBool('${widget.kitname}SWA1x21Fixed') ?? false;
      x22Fixed = prefs.getBool('${widget.kitname}SWA1x22Fixed') ?? false;
      x21Controller.text = x21Text;
      x22Controller.text = x22Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SWA1x21', x21Text);
    prefs.setString('${widget.kitname}SWA1x22', x22Text);
    prefs.setBool('${widget.kitname}SWA1x21Fixed', x21Fixed);
    prefs.setBool('${widget.kitname}SWA1x22Fixed', x22Fixed);
  }

  void calculateOutput() {
    double? x21 = double.tryParse(x21Text);
    double? x22 = double.tryParse(x22Text);
    double? x23 = double.tryParse(x23Controller.text);


    if (x21 != null && x23 != null && x22!= null) {
      output = (x22 + 20*(log10(x23)-log10(x21))).toStringAsFixed(3);

      // outputDBM = result.toStringAsFixed(3);
    } else {
      output = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              floatingLabelStyle: TextStyle(fontSize: 14),
              contentPadding: EdgeInsets.symmetric(horizontal: 12.0,vertical: 20),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Sector Width Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Required HSW (UHSW+LHSW = 0.24θ) (in Deg)', x21Controller, x21Fixed, () {
              x21Fixed = !x21Fixed;
              x21Text = x21Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            inputField('Existing Alignment COU SBO Level (in dB)', x22Controller, x22Fixed, () {
              x22Fixed = !x22Fixed;
              x22Text = x22Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x23Controller,
              decoration: InputDecoration(
                labelText: ' Measured Half Sector Width on air as per FIU (in Deg)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (output.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('Output: $output', style: TextStyle(fontSize: 18)),
              ),
          ],
        ),
      ),
      ))]));
  }
}

class SDMMod1Ajustment extends StatefulWidget {
  final String kitname;
  SDMMod1Ajustment({required this.kitname});
  @override
  _modulationLevel1AdjustmentState createState() => _modulationLevel1AdjustmentState();
}

class _modulationLevel1AdjustmentState extends State<SDMMod1Ajustment> {
  TextEditingController x31Controller = TextEditingController();
  TextEditingController x32Controller = TextEditingController();


  String x31Text = '';
  String x32Text = '';
  bool x31Fixed = false;
  String outputSDM = '';

  @override
  void initState() {
    super.initState();
    loadValues();
  }

  Future<void> loadValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    setState(() {
      x31Text = prefs.getString('${widget.kitname}SDM1x31') ?? '';
      x31Fixed = prefs.getBool('${widget.kitname}SDM1x31Fixed') ?? false;
      x31Controller.text = x31Text;
      x32Controller.text = x32Text;
    });
  }

  Future<void> saveValues() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    prefs.setString('${widget.kitname}SDM1x31', x31Text);
    prefs.setBool('${widget.kitname}SDM1x31Fixed', x31Fixed);
  }

  void calculateOutput() {
    double? x31 = double.tryParse(x31Text);
    double? x32 = double.tryParse(x32Controller.text);


    if (x31 != null && x32 != null) {
      outputSDM = (x31 + x32).toString();
    } else {
      outputSDM = '';
    }

    saveValues();
    setState(() {});
  }

  Widget inputField(String label, TextEditingController controller, bool isFixed, Function onFix) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isFixed,
            decoration: InputDecoration(
              labelText: label,
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 8.0),
            ),
            keyboardType: TextInputType.number,
          ),
        ),
        SizedBox(width: 8),
        ElevatedButton(
          onPressed: () {
            setState(() {
              onFix();
            });
          },
          child: Text(isFixed ? 'Edit' : 'Fix'),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('SDM/Mod Sum Adjustment')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            inputField('Existing Alignment SDM', x31Controller, x31Fixed, () {
              x31Fixed = !x31Fixed;
              x31Text = x31Controller.text;
              saveValues();
            }),
            SizedBox(height: 8),
            TextField(
              controller: x32Controller,
              decoration: InputDecoration(
                labelText: 'SDM Adjustment Required as per FIU (in %)',
                border: OutlineInputBorder(),
                contentPadding: EdgeInsets.all(8.0),
              ),
              keyboardType: TextInputType.number,
            ),
            SizedBox(height: 8),
           
            ElevatedButton(
              onPressed: calculateOutput,
              child: Text('Calculate'),
            ),
            if (outputSDM.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 16.0),
                child: Text('New Alignment SDM : $outputSDM', style: TextStyle(fontSize: 18)),
              ),
            SizedBox(height: 30,),
            Padding(padding: const EdgeInsets.only(top: 10.0),
            child: Text('Note:Check monitor window and increase or decrease accordingly',style:TextStyle(color: Colors.red))),
          ],
        ),
      ),
      ))]));
  }
}

class PositionAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Position Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check/click the CL Test Signal 1 for alarm on 90 side.
    2)	Check/click the CL Test Signal 2 for alarm on 150 side.

If the alarm does not appear, change the value in the box against CL Test Signal 1 or CL Test Signal 2  by the up/down arrow as per FIU.

To Normalize: Check/click the CL test off.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

class WidthAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Width Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check/click the Narrow for narrow alarm.
    2)	Check/click the Wide for Wide alarm.

If the alarm does not appear, change the value in the box against the Narrow check button or Wide Check button by the up/down arrow.

To Normalize: Check/click the DS test off.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

class PowerAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Power Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check the COU or CLR under RF Test attenuation. 

Power alarm is always be given with 1dB RF attenuation for Dual frequency ILS and with 
3dB RF attenuation for single frequency ILS.

To Normalize: Un check the RF Test attenuation.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

class ClearanceAlarm1 extends StatelessWidget{
   @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text('Position Alarm',style: TextStyle(fontSize: 18),)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('''
On the Alarm Limit Check tab of the flight check window, 
    1)	Check/click the Wide for clearance alarm. 

If the alarm does not appear, change the value in the box against the Wide check button by the up/down arrow.

To Normalize: Check/click the CLR test off.

''',style: TextStyle(fontSize: 18),)
            ]))))]));
}
}

// FacilityField model
class FacilityField {
  String value;
  bool fixed;
  FacilityField({required this.value, required this.fixed});

  Map<String, dynamic> toJson() => {'value': value, 'fixed': fixed};
  factory FacilityField.fromJson(Map<String, dynamic> json) =>
      FacilityField(value: json['value'], fixed: json['fixed']);
}

// Facility model
class Facility {
  final String name;
  final List<FacilityField> fields;
  final List<FacilityAttachment> attachments;
  Facility({required this.name, required this.fields,this.attachments = const []});

  Map<String, dynamic> toJson() => {
        'name': name,
        'fields': fields.map((f) => f.toJson()).toList(),
      };
  factory Facility.fromJson(Map<String, dynamic> json) => Facility(
        name: json['name'],
        fields: (json['fields'] as List)
            .map((f) => FacilityField.fromJson(f))
            .toList(),
      );
}

class FacilityAttachment{
  final String fileName;
  final String filePath;
  final DateTime addeddate;
  FacilityAttachment({required this.fileName,required this.filePath,required this.addeddate});
}

// Save facilities to SharedPreferences
Future<void> saveFacilities(List<Facility> facilities) async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String jsonString = jsonEncode(facilities.map((f) => f.toJson()).toList());
  await prefs.setString('facilities', jsonString);
}

// Load facilities from SharedPreferences
Future<List<Facility>> loadFacilities() async {
  SharedPreferences prefs = await SharedPreferences.getInstance();
  String? jsonString = prefs.getString('facilities');
  if (jsonString == null) return [];
  List<dynamic> jsonList = jsonDecode(jsonString);
  return jsonList.map((f) => Facility.fromJson(f)).toList();
}

// StationScreen
class StationScreen extends StatefulWidget {
  @override
  _StationScreenState createState() => _StationScreenState();
}

class _StationScreenState extends State<StationScreen> {
  List<Facility> facilities = [];

  @override
  void initState() {
    super.initState();
    _loadFacilities();
  }

  Future<void> _loadFacilities() async {
    facilities = await loadFacilities();
    setState(() {});
  }

  Future<void> addFacility(Facility fac) async {
    setState(() {
      facilities.add(fac);
    });
    await saveFacilities(facilities);
  }

  Future<void> updateFacility(int index, Facility fac) async {
    setState(() {
      facilities[index] = fac;
    });
    await saveFacilities(facilities);
  }

  Future<void> deletefacility(int index)async{
    setState(() {
      facilities.removeAt(index);
    });
    await saveFacilities(facilities);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Navaids Facilities')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            Row(
              children: [
                Text('Facility Details',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Spacer(),
                ElevatedButton(
                    onPressed: () async {
                      final newfacility = await Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (context) => AddfacilityScreen()));
                      if (newfacility != null) await addFacility(newfacility);
                    },
                    child: Text("ADD",style: TextStyle(fontSize: 18),)),
              ],
            ),
            Expanded(
              child: ListView.builder(
                itemCount: facilities.length,
                itemBuilder: (context, idx) => ListTile(
                  title: Text(facilities[idx].name),
                  trailing: IconButton(
                    onPressed: (){
                      showDialog(context: context, builder: (BuildContext context){
                        return AlertDialog(
                          title: Text('Delete Facility'),
                          content: Text('Are you sure you want to delete "${facilities[idx].name}"'),
                          actions: [   
                            TextButton(onPressed: (){
                              Navigator.of(context).pop();
                            }, child: Text('Cancel')),
                            TextButton(onPressed: (){
                              deletefacility(idx);
                              Navigator.of(context).pop();
                            }, child: Text('Delete',style: TextStyle(color: Colors.red),))
                          ],
                        );
                      });
                    }, icon: Icon(Icons.delete,color: Colors.red,)),
                  onTap: () async {
                    final updated = await Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => FacilityDetailScreen(
                                fac: facilities[idx], index: idx)));
                    if (updated != null) await updateFacility(idx, updated);
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

// AddfacilityScreen
class AddfacilityScreen extends StatefulWidget {
  @override
  _AddfacilityScreenState createState() => _AddfacilityScreenState();
}

class _AddfacilityScreenState extends State<AddfacilityScreen> {
  TextEditingController facilityController = TextEditingController();
  // Field names as per the image
  final List<String> fieldNames = [
    'Make/Model',
    'Frequency',
    'Emission',
    'Ident',
    'Site Elevation',
    'Coordinates',
    'RF Power (Tx-1/Tx-2)',
    'Commissioned C/W',
    'Current C/W',
    'Date of Installation of EQPT',
    'Commissioning Date',
    'Last Calibration Date',
    'Next Calibration Due Date',
    'UPS Make/Model & Capacity',
    'Date of Installation of UPS Batteries',
    'Date of replacement of UPS batteries',
    'EQPT batteries Make/Model & Capacity',
    'Date of installation of EQPT batteries',
    'Date of replacement of EQPT batteries',
    'Any other relevant Information',
  ];
  List<TextEditingController> controllers = List.generate(20, (_) => TextEditingController());
  bool allFixed = false;
  File? _selectedFile;
  String? _fileName;
  bool isProcessing = false; // <-- loading state
  void toggleAllFixed() {
    setState(() {
      allFixed = !allFixed;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Add Facility')),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextField(
                controller: facilityController,
                decoration: InputDecoration(labelText: 'Facility Name'),
              ),
              SizedBox(height: 16),
              for (int i = 0; i < fieldNames.length; i++)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child:SizedBox(
                    width: 550,
                  child: TextField(
                    controller: controllers[i],
                    enabled: !allFixed,
                    decoration: InputDecoration(
                      labelText: fieldNames[i],
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),),
              SizedBox(height: 12),
              ElevatedButton.icon(
                onPressed: () async {
                  try {
                    FilePickerResult? result = await FilePicker.platform.pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                      
                    );

                    if (result != null) {
                      setState(() {
                        _selectedFile = File(result.files.single.path!);
                        _fileName = result.files.single.name;
                      });
                    }
                  } catch (e) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error picking file: $e'),
                        backgroundColor: Colors.red,
                      ),
                    );
                  }
                },
                label: Text(_fileName ?? 'Add Attachment'),
                icon: Icon(Icons.attach_file),
              ),
              SizedBox(height: 24,),
              Row(
                children: [
                  ElevatedButton(
                    onPressed: toggleAllFixed,
                    child: Text(allFixed ? 'Edit All' : 'Fix All'),
                  ),
                  Spacer(),
                  ElevatedButton(
                    onPressed: isProcessing ? null : () async {
                      setState(() { isProcessing = true; });
                      if(facilityController.text.isEmpty){
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Please add the Facility Name '),backgroundColor: Colors.red,));
                        setState(() { isProcessing = false; });
                        return;
                      }
                      String name = facilityController.text;
                      List<FacilityField> fields = List.generate(
                        fieldNames.length,
                        (i) => FacilityField(value: controllers[i].text, fixed: allFixed),
                      );
                      // Indices of the 3 fields in fieldNames
                      final indices = [12, 15, 18];
                      final notificationTitles = [
                        'Next Calibration Due Date',
                        'Date of replacement of UPS batteries',
                        'Date of replacement of EQPT batteries'
                      ];

                      for (int i = 0; i < indices.length; i++) {
                        final idx = indices[i];
                        final dateStr = controllers[idx].text;
                        final date = parseDate(dateStr);
                        if (date != null) {
                          await scheduleFacilityNotifications(
                            title: 'Reminder: ${notificationTitles[i]}',
                            body: 'The due date for ${notificationTitles[i]} is approaching for $name.',
                            dueDate: date,
                            notificationId: idx * 1000 + DateTime.now().millisecondsSinceEpoch % 1000, // unique id
                          );
                        }
                      }
                      // Find the soonest notification date
                      DateTime? soonest;
                      for (int i = 0; i < indices.length; i++) {
                        final idx = indices[i];
                        final dateStr = controllers[idx].text;
                        final date = parseDate(dateStr);
                        if (date != null) {
                          final notifyTime = date.subtract(Duration(days: 7));
                          if (soonest == null || notifyTime.isBefore(soonest)) {
                            soonest = notifyTime;
                          }
                        }
                      }

                      // After scheduling all reminders
                      if (soonest != null) {
                        await showImmediateNotification(
                          'Reminder Scheduled',
                          'A reminder will be sent on ${soonest.day}/${soonest.month}/${soonest.year}.',
                        );
                      } else {
                        await showImmediateNotification(
                          'No Reminder Scheduled',
                          'No valid reminder dates were found.',
                        );
                      }
                      setState(() { isProcessing = false; });
                      Navigator.pop(context, Facility(name: name, fields: fields));
                    },
                    child: isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('ADD'),
                  ),
                ],
              ),
              
            ],
          ),
        ),
      ),
    );
  }
}

// FacilityDetailScreen
class FacilityDetailScreen extends StatefulWidget {
  final Facility fac;
  final int index;
  FacilityDetailScreen({required this.fac, required this.index});
  @override
  _FacilityDetailScreenState createState() => _FacilityDetailScreenState();
}

class _FacilityDetailScreenState extends State<FacilityDetailScreen> { 
  late List<TextEditingController> controllers;
  bool allfixed = false;
  File? _selectedFile;
  String? _fileName;
  final List<String> fieldNames = [
    'Make/Model',
    'Frequency',
    'Emission',
    'Ident',
    'Site Elevation',
    'Coordinates',
    'RF Power (Tx-1/Tx-2)',
    'Commissioned C/W',
    'Current C/W',
    'Date of Installation of EQPT',
    'Commissioning Date',
    'Last Calibration Date',
    'Next Calibration Due Date',
    'UPS Make/Model & Capacity',
    'Date of Installation of UPS Batteries',
    'Date of replacement of UPS batteries',
    'EQPT batteries Make/Model & Capacity',
    'Date of installation of EQPT batteries',
    'Date of replacement of EQPT batteries',
    'Any other relevant Information',
  ];
  bool isProcessing = false; // <-- loading state
  @override
  void initState() {
    super.initState();
    controllers = widget.fac.fields
        .map((f) => TextEditingController(text: f.value))
        .toList();
    allfixed = widget.fac.fields.every((f) => f.fixed);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.fac.name),
        actions: [
          IconButton(
            icon: Icon(Icons.save),
            onPressed: isProcessing ? null : () async {
              setState(() { isProcessing = true; });
              List<FacilityField> updatedFields = List.generate(fieldNames.length, (i) => FacilityField(value: controllers[i].text, fixed: allfixed));
              final indices = [12, 15, 18];
              final notificationTitles = [
                'Next Calibration Due Date',
                'Date of replacement of UPS batteries',
                'Date of replacement of EQPT batteries'
              ];

              for (int i = 0; i < indices.length; i++) {
                final idx = indices[i];
                final dateStr = controllers[idx].text;
                final date = parseDate(dateStr);
                if (date != null) {
                  await scheduleFacilityNotifications(
                    title: 'Reminder: ${notificationTitles[i]}',
                    body: 'The due date for ${notificationTitles[i]} is approaching for ${widget.fac.name}.',
                    dueDate: date,
                    notificationId: idx * 1000 + DateTime.now().millisecondsSinceEpoch % 1000, // unique id
                  );
                }
              }
              // Find the soonest notification date
              DateTime? soonest;
              for (int i = 0; i < indices.length; i++) {
                final idx = indices[i];
                final dateStr = controllers[idx].text;
                final date = parseDate(dateStr);
                if (date != null) {
                  final notifyTime = date.subtract(Duration(days: 7));
                  if (soonest == null || notifyTime.isBefore(soonest)) {
                    soonest = notifyTime;
                  }
                }
              }

              // After scheduling all reminders
              if (soonest != null) {
                await showImmediateNotification(
                  'Reminder Scheduled',
                  'A reminder will be sent on ${soonest.day}/${soonest.month}/${soonest.year}.',
                );
              } else {
                await showImmediateNotification(
                  'No Reminder Scheduled',
                  'No valid reminder dates were found.',
                );
              }
              setState(() { isProcessing = false; });
              Navigator.pop(context,Facility(name: widget.fac.name, fields: updatedFields));
            },
          )
        ],
      ),
      body: SingleChildScrollView(
       child : Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Expanded(
            for(int i=0; i<fieldNames.length;i++)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8.0),
              child :SizedBox(
                width: 550,
              child: TextField(
                controller: controllers[i],
                enabled: !allfixed,
                decoration: InputDecoration(labelText: fieldNames[i],
                border : OutlineInputBorder(),),
                
              ),
            ),),
            SizedBox(height: 12),
            ElevatedButton.icon(
              onPressed: () async {
                try {
                  FilePickerResult? result = await FilePicker.platform.pickFiles(
                    type: FileType.custom,
                    allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
                  );

                  if (result != null) {
                    setState(() {
                      _selectedFile = File(result.files.single.path!);
                      _fileName = result.files.single.name;
                    });
                  }
                } catch (e) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text('Error picking file: $e'),
                      backgroundColor: Colors.red,
                    ),
                  );
                }
              },
              label: Text(_fileName ?? 'Add Attachment'),
              icon: Icon(Icons.attach_file),
            ),
            SizedBox(height: 24,),
            Row(
              children: [
                ElevatedButton(onPressed: (){
                  setState(() {
                    allfixed = !allfixed;
                  });
                }, child: Text(allfixed ? 'Edit All' : 'Fix All')),
                Spacer(),
                ElevatedButton(
                onPressed: isProcessing ? null : () async {
                  setState(() { isProcessing = true; });
                  List<FacilityField> updatedFields = List.generate(fieldNames.length, (i) => FacilityField(value: controllers[i].text, fixed: allfixed));
                  final indices = [12, 15, 18];
                  final notificationTitles = [
                    'Next Calibration Due Date',
                    'Date of replacement of UPS batteries',
                    'Date of replacement of EQPT batteries'
                  ];

                  for (int i = 0; i < indices.length; i++) {
                    final idx = indices[i];
                    final dateStr = controllers[idx].text;
                    final date = parseDate(dateStr);
                    if (date != null) {
                      await scheduleFacilityNotifications(
                        title: 'Reminder: ${notificationTitles[i]}',
                        body: 'The due date for ${notificationTitles[i]} is approaching for ${widget.fac.name}.',
                        dueDate: date,
                        notificationId: idx * 1000 + DateTime.now().millisecondsSinceEpoch % 1000, // unique id
                      );
                    }
                  }
                  // Find the soonest notification date
                  DateTime? soonest;
                  for (int i = 0; i < indices.length; i++) {
                    final idx = indices[i];
                    final dateStr = controllers[idx].text;
                    final date = parseDate(dateStr);
                    if (date != null) {
                      final notifyTime = date.subtract(Duration(days: 7));
                      if (soonest == null || notifyTime.isBefore(soonest)) {
                        soonest = notifyTime;
                      }
                    }
                  }

                  // After scheduling all reminders
                  if (soonest != null) {
                    await showImmediateNotification(
                      'Reminder Scheduled',
                      'A reminder will be sent on ${soonest.day}/${soonest.month}/${soonest.year}.',
                    );
                  } else {
                    await showImmediateNotification(
                      'No Reminder Scheduled',
                      'No valid reminder dates were found.',
                    );
                  }
                  setState(() { isProcessing = false; });
                  Navigator.pop(context,Facility(name: widget.fac.name, fields: updatedFields));
                },
                child: isProcessing ? SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : Text('Save'),
              ),
              ],
            ),
            // ... existing code ...
          ],
        ),
      ),
    ));
  }
}

class PhasingGlidePath extends StatelessWidget {
  final String title;
  PhasingGlidePath(this.title);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle("Glide Path Antenna Feeds"),
            sectionBody("Antenna feeds for M-Array ILS Glide path system:\n\n"),
            Image.asset('assets/csb.png'),
            sectionTitle("Adjustment Procedure:"),
            bulletPoints(['''	This procedure provide a method to align the antenna system mechanically as well as electronically after mechanical installation .''',
'''It is essential to mechanically position the antenna element on the mast accurately in order to achieve required glide path angle and clearance requirements.''',
'''The positioning data can be calculated from the following parameters:
            a) Average forward slope angle (FSL)
            b) Average sideways slope angle (SSL)
            c) GP zero (GP reference point near or the base of GP mast)
            d) Glide path angle.
            e) GP RF channel frequency.
            f) RDH ''',
'''Based on these parameter the Longitudinal distance from Approach Threshold and Lateral distance from RWY C/L of GP antenna is decided.
''']),
            sectionTitle("Mechanical Adjustments:"),
            sectionTitle("Antenna system alignment:"),

            bulletPoints(['''
Antenna Mast should be perpendicular to the RWY C/L .''',
'''Tolerance  90⁰± 1⁰''',
'''Base of the mast and antenna should be properly leveled.''',
'''Antenna element should be aligned along the straight line, which shall be perpendicular to the average forward slope.''',
'''The spacing between antenna element shall be equal.
''']),
            sectionTitle("Antenna heights and spacing:"),
            bulletPoints(['''The spacing between antenna element shall be equal.''',
'''The spacing shall be referenced to GP ZERO which is the intercept between average forward slope  and GP mast.''',
'''The  middle antenna height is critical to glide path angle. 
A 5 cm shift of the middle antenna, changes the glide angle by 0.02° (4µA) .''',
'''Antenna spacing tolerance ± 3 cm
''']),
            Image.asset('assets/horizontal.png'),
            sectionTitle("Antenna element offset"),
            bulletPoints(['''The side offset of antenna element shall be accurately adjusted.''',
'''Orientation is such that the upper antenna is closer to the runway than middle antenna .''',
'''The middle antenna shall be closer to the runway than the lower antenna''',
'''Tolerance ±3 cm .
''']),
            Image.asset('assets/vertical.png'),

            sectionTitle("Electrical Adjustments"),
            
            simpleTable([
              ["Antenna Cable", "Physical Length", "Amplitude (dB)", "Phase (deg)"],
              ["Lower (1)", "25 m", "-4.15", "133.90"],
              ["Middle (4)", "25 m", "-4.18", "133.10"],
              ["Upper (7)", "25 m", "-4.16", "133.60"]
            ]),
            bulletPoints(["Using a VNA, Measure open-end return phase for each cable.",
            "VNA must be calibrated in single port at GP Channel frequency. ",
            "The cable  pair shall be matched within ±4.0° return phase which is equal to ±2.0° true phase."
            ]),
            Image.asset('assets/cable.png'),
            sectionBody("Monitor Cable Lengths:"),
            sectionBody('''
There are Six Monitor cable from GP Antenna.
     1.   2 and 3   (Lower Antenna Monitor Pickup to equipment)
     2.   5 and 6   (Middle Antenna Monitor pickup to equipment)
     3.   8 and 9   (Upper Antenna Monitor pickup to equipment)
'''),
            simpleTable([
              ["Monitor", "Physical Length", "Amplitude (dB)", "Phase (deg)"],
              ["2 Lower", "25 m", "-4.18", "130.0"],
              ["3 Lower", "25 m", "-4.21", "129.8"],
              ["5 Middle", "25 m", "-4.25", "129.5"],
              ["6 Middle", "25 m", "-4.22", "129.9"],
              ["8 Upper", "25 m", "-4.14", "131.2"],
              ["9 Upper", "25 m", "-4.12", "131.0"],
            ]),
            bulletPoints(['''
            Using a VNA, Measure open-end return phase for each cable.''',
            "VNA must be calibrated in single port at GP Channel frequency. ",
            "The cable  pair shall be matched within ±4.0° return phase which is equal to ±2.0° true phase."
            ]),
            sectionTitle("Example: Making Cable of Equal Length"),
            bulletPoints(['''Suppose we have to make Three cable A1,A2 and A3 of same electrical length.''',
            '''First cut all three cable of equal physical length''',
            '''Make connector at one end of each cable.''',
'''Measure the electrical length of each cable ,suppose at this point of measurement the cable length are as follows
      A1=-5.61dB/-31.01 degree
      A2=-5.38 dB/-19.30 degree
      A3=-5.33 dB/-12.32 degree''',
'''In this case the cable no A3 is smallest, so we have to cut other two cable A1 and A2. ''',
'''In case of GP the one ring of cable cutting is equal to 3 degree electrical length''',
'''After cutting cable the new length became 
      A1=-5.40dB/-12.66 degree
      A2=-5.31dB/-12.53 degree
      A3=-5.33 dB/-12.32 degree''',
'''After this make connectors at other end of the all cable.''',
'''After making connector again measure the cable length of all three cable. That would be the final electrical length of the cable.'''
]),

            sectionTitle("Antenna Return Loss / VSWR"),
            bulletPoints(["Measure return loss for each antenna element ",
            "Tolerance: -20 dB maximum.",
            "Measure VSWR of each antenna.",
            "Measure Impedance of each antenna."]),
            simpleTable([
              ["Antenna", "VSWR", "Return Loss", "Impedance"],
              ["A1 (Lower)", "1.08", "-28.45", "49.64 / -3.19"],
              ["A2 (Middle)", "1.09", "-27.50", "49.33 / -0.19"],
              ["A3 (Upper)", "1.08", "-28.40", "50.19 / -0.47"],
            ]),
            sectionBody("\n"),
            Image.asset('assets/cable-1.png'),
            sectionTitle("Phase and Amplitude Transfer"),
            bulletPoints(["Phase amplitude transfer measurement confirms that the complete loop from Antenna cable to Monitor cable via Antenna is ok.",
            "Measure relative transfer phase and amplitude for each Antenna to Monitor cable signal path in reference to A1- to-M1.",
            "If a particular signal path measures more than -3°,the associated monitor cable should be trimmed. On the on the hand ,if a signal path measures more than +3° as the highest positive value ,the other two monitor cable should be trimmed.",
            "Amplitude tolerance:±0.2 dB if this amplitude tolerance is exceeded, this indicates a possible error in the monitor loop"]),
            simpleTable([
              ["Antenna / Monitor", "Amplitude (dB)", "Phase (deg)"],
              ["A1 to M1", "-25.79", "-172.95"],
              ["A1 to M2", "-25.55", "-177.41"],
              ["A2 to M1", "-25.76", "-173.12"],
              ["A2 to M2", "-25.44", "-176.85"],
              ["A3 to M1", "-25.67", "-173.05"],
              ["A3 to M2", "-25.38", "-176.10"],
            ]),
            sectionBody("\n"),
            Image.asset('assets/cable-2.png'),
            sectionTitle("NPO RTS GP 734 Phasing Procedure"),
            bulletPoints(['''In order to complete the configuration of the GP 734 parameters, the antenna system phasing procedure must be performed. ''',

'''The purpose of the GP 734 phasing for each kit is to select such phase differences between antennas 1, 2 and 3, that the signals on the Course of all antennas in the "far area" become in-phase (anti-phase, depending on the measurement point and antenna number). ''',

'''The phasing is performed alternately for Antenna 1 and Antenna 2, then for Antenna 1 and Antenna 3.

Antenna designations:– 

Antenna 1 — LOWER ANT
Antenna 2 — MIDDLE ANT
Antenna 3 — UPPER ANT''']),
            sectionTitle("Phasing Antenna 1 to Antenna 2"),
            bulletPoints(['Set the parameters shown below for Antenna 1 and Antenna 2 in the "Modulators settings" widget.']),
            Image.asset('assets/table-1.png'),
            bulletPoints([
'''Before phasing, set the PIR antenna at a distance of 500...1000 meters from the runway threshold, towards the approach, opposite the GP 734 Antenna or closer to the runway C/L. '''
'''Measure the GP 734 parameters and make sure, that the SDM  value is equal to (80 ± 5) %. '''
'''Make the DDM parameter value, equal to (0 ± 1.5) % by changing the "Phase offset" parameter for Antenna 2 in the "Modulator settings" widget.
''']),
            Image.asset('assets/table-2.png'),
            bulletPoints(['''
Change the phase value of Antenna 2 to +90 or −90. The correct phase value ensures that the DDM parameter value, is positive. Record the resulting phase value''']),
            sectionTitle("Phasing Antenna 1 to Antenna 3"),
            bulletPoints(['Set the parameters shown in Figure below for Antenna 1 and Antenna 3 in the "Modulators settings" widget.']),
            Image.asset('assets/table-3.png'),
            bulletPoints(['Make the DDM parameter value, equal to (0 ± 1.5) % by changing the "Phase offset" parameter for Antenna 3 in the "Modulator settings" widget .']),
            Image.asset('assets/table-4.png'),
            bulletPoints(['Change the phase value of Antenna 3 to +90 or −90. The correct phase value ensures that the DDM parameter value, is negative. Record the resulting phase value.']),
          ],
        ),
      ),
    ))]));
  }

  Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
  );

  Widget sectionBody(String text) => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16)),
  );

  Widget bulletPoints(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map((item) => Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Text("• $item", style: TextStyle(fontSize: 16)),
            ))
        .toList(),
  );

  Widget simpleTable(List<List<String>> rows) => Table(
    border: TableBorder.all(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    columnWidths: {
      0: IntrinsicColumnWidth(),
      1: IntrinsicColumnWidth(),
      2: IntrinsicColumnWidth(),
      3: IntrinsicColumnWidth(),
    },
    children: rows.map((row) {
      return TableRow(
        children: row
            .map((cell) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(cell, style: TextStyle(fontSize: 14)),
                ))
            .toList(),
      );
    }).toList(),
  );
}

class PhasingLocalizer extends StatelessWidget{
  final String title;
  PhasingLocalizer(this.title);
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body:Column(
      children:[
      Container(
        width: double.infinity,
        padding: EdgeInsets.all(16.0),
        color: Colors.blue,
       child:Row(
              mainAxisAlignment: MainAxisAlignment.center, // for padding and bringing app and title to middle
              // crossAxisAlignment: CrossAxisAlignment.baseline,
        children:[
          Image.asset('assets/app_icon.jpg',
          height:30,),
          SizedBox(width: 10),
          Text('NavCal Pro',
          style:TextStyle(fontSize: 22, fontWeight:FontWeight.bold),),],
            ),),
      Expanded(child: Scaffold(
      appBar: AppBar(title: Text(title)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            sectionTitle('Phasing of the Course CSB, Clearance CSB and Course SBO , Clearance SBO:'),
            sectionBody('''
The Course and Clearance phasing is allowed only in cases of the Modulator replacement or equipment ground adjustment before flight testing. 

1.	Run "Console 734" software application. Select Loc 734 from the device list. Go to the "Parameter settings" menu. 
2.	Turn on the Loc 734 first kit. 
3.	In order to perform the Course Modulator (Clearance Modulator) phasing connect the analyzer to the control output 7, 9 or 14 of an antenna — "7 F.C." (for 16 element antenna), "9 F.C." (for 20 element antenna) or "14 F.C." (for 32 element antenna) on the Divider, respectively. 
4.	Set the power parameters ("PCSB_active", "PSBO_active") of the Clearance Modulator (Course Modulator) to 0 (-20 dbm) using "Console 734" software application. 

'''),
            Image.asset('assets/bigtable.png'),
            sectionBody('''
5.	Measure DDM values with the analyzer. By changing the "Phase" parameter in the Course Modulator (Clearance Modulator) settings, achieve a DDM value equal to 0.0 ± 0.5 %. Save the received phase value. 
6.	Set the initial power parameters of the Course Modulator using "Console 734" software application. 
7.	Repeat steps from paragraphs 3–6 similarly for the Clearance Modulator. 
8.	Restore the original power settings. 
9.	Repeat steps from paragraphs 3–8 for the second kit of the equipment. 

'''),
          ]))))]));
}
     Widget sectionTitle(String text) => Padding(
    padding: const EdgeInsets.only(top: 24.0, bottom: 8.0),
    child: Text(text, style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
  );

  Widget sectionBody(String text) => Padding(
    padding: const EdgeInsets.only(top: 8.0),
    child: Text(text, style: TextStyle(fontSize: 16)),
  );

  Widget bulletPoints(List<String> items) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: items
        .map((item) => Padding(
              padding: const EdgeInsets.only(left: 16.0, bottom: 4.0),
              child: Text("• $item", style: TextStyle(fontSize: 16)),
            ))
        .toList(),
  );
    Widget simpleTable(List<List<String>> rows) => Table(
    border: TableBorder.all(),
    defaultVerticalAlignment: TableCellVerticalAlignment.middle,
    columnWidths: {
      0: IntrinsicColumnWidth(),
      1: IntrinsicColumnWidth(),
      2: IntrinsicColumnWidth(),
      3: IntrinsicColumnWidth(),
    },
    children: rows.map((row) {
      return TableRow(
        children: row
            .map((cell) => Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: Text(cell, style: TextStyle(fontSize: 14)),
                ))
            .toList(),
      );
    }).toList(),
  );
}

DateTime? parseDate(String dateString) {
  try {
    return DateFormat('dd/MM/yyyy').parseStrict(dateString);
  } catch (e) {
    return null;
  }
}

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> scheduleFacilityNotifications({
  required String title,
  required String body,
  required DateTime dueDate,
  required int notificationId,
}) async {
  // final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // Calculate the notification time (1 week before, or tomorrow if less than a week)
  DateTime now = DateTime.now();
  DateTime notifyTime = dueDate.subtract(Duration(days: 7));
  if (notifyTime.isBefore(now)) {
    notifyTime = now.add(Duration(days: 1));
  }

  // Only schedule if the notification time is in the future
  if (notifyTime.isAfter(now)) {
    print('schedule the notification for $notifyTime');
    await flutterLocalNotificationsPlugin.zonedSchedule(
      notificationId,
      title,
      body,
      tz.TZDateTime.from(notifyTime, tz.local),
      NotificationDetails(
        android: AndroidNotificationDetails(
          'facility_channel',
          'Facility Reminders',
          channelDescription: 'Reminders for facility maintenance',
          importance: Importance.max,
          priority: Priority.high,
          actions: <AndroidNotificationAction>[
            AndroidNotificationAction('snooze', 'Remind me after one day'),
            AndroidNotificationAction('done', 'Done'),
          ],
        ),
      ),
      androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle, // <-- ADD THIS LINE
      payload: 'facility_reminder',
      matchDateTimeComponents: DateTimeComponents.dateAndTime,
    );
    print('notification scheduled');

  }
}


Future<void> initializeNotifications() async {
  const AndroidInitializationSettings initializationSettingsAndroid =
      AndroidInitializationSettings('@mipmap/ic_launcher');
  const WindowsInitializationSettings initializationSettingsWindows = 
      WindowsInitializationSettings(appName: "NavCal Pro", appUserModelId: "Likhith", guid: "123e4567-e89b-12d3-a456-426614174000");
  final InitializationSettings initializationSettings = InitializationSettings(
    android: initializationSettingsAndroid,
    windows : initializationSettingsWindows,
  );
  await flutterLocalNotificationsPlugin.initialize(
    initializationSettings,
    onDidReceiveNotificationResponse: (NotificationResponse response) async {
      if (response.actionId == 'snooze') {
        // Reschedule for next day
        // You need to know which notification/date this was for!
      } else if (response.actionId == 'done') {
        // Cancel this notification
        await flutterLocalNotificationsPlugin.cancel(response.id!);
      }
    },
  );
}

// final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

Future<void> requestNotificationPermission() async {
  // iOS
  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>()
      ?.requestPermissions(alert: true, badge: true, sound: true);

  // Android 13+ (API 33+)
  if (await Permission.notification.isDenied) {
    await Permission.notification.request();
  }
}

Future<void> showImmediateNotification(String title, String body) async {
  await flutterLocalNotificationsPlugin.show(
    0, // Notification ID
    title,
    body,
    NotificationDetails(
      android: AndroidNotificationDetails(
        'facility_channel',
        'Facility Reminders',
        channelDescription: 'Reminders for facility maintenance',
        importance: Importance.max,
        priority: Priority.high,
      ),
    ),
  );
}
