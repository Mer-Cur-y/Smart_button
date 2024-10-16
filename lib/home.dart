import 'package:flutter/material.dart';
import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';
import 'database_helper.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final DatabaseHelper _databaseHelper = DatabaseHelper();
  List<Map<String, dynamic>> _users = [];
  late MqttServerClient _client;

  bool _isMqttConnected = false; 
  bool _isWifiConnected = false;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
    _setupMqtt();
    _checkWifiConnection();
  }

  Future<void> _setupMqtt() async {
    _client = MqttServerClient('broker.hivemq.com', 'smartbutton');
    _client.port = 1883;
    _client.logging(on: true);
    _client.keepAlivePeriod = 20;
    _client.onDisconnected = _onDisconnected;
    _client.onConnected = _onConnected;
    _client.onSubscribed = _onSubscribed;

    final connMessage = MqttConnectMessage()
        .withClientIdentifier('smartbutton')
        .startClean()
        .withWillTopic('willtopic')
        .withWillMessage('Client Disconnected')
        .withWillQos(MqttQos.atLeastOnce);
    _client.connectionMessage = connMessage;

    try {
      await _client.connect();
      setState(() {
        _isMqttConnected = true;
      });
      print('MQTT connected successfully.');
    } catch (e) {
      setState(() {
        _isMqttConnected = false;
      });
      print('MQTT connection failed: $e');
    }
  }

  void _onConnected() {
    print('Connected to MQTT broker');
  }

  void _onDisconnected() {
    setState(() {
      _isMqttConnected = false;
    });
    print('Disconnected from MQTT broker');
  }

  void _onSubscribed(String topic) {
    print('Subscribed to topic: $topic');
  }

  Future<void> _fetchUsers() async {
    final db = await _databaseHelper.database;
    final List<Map<String, dynamic>> users = await db.query('users');
    setState(() {
      _users = users;
    });
  }

  void _publishMessage(String topic, String message) {
    if (!_isMqttConnected) {
      print('Cannot publish message, MQTT not connected');
      return;
    }
    final builder = MqttClientPayloadBuilder();
    builder.addString(message);
    _client.publishMessage(topic, MqttQos.atLeastOnce, builder.payload!);
  }

  Future<void> _checkWifiConnection() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      _isWifiConnected = connectivityResult == ConnectivityResult.wifi;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Container(
          margin: EdgeInsets.symmetric(vertical: 20),
          child: Text(
            'Smart Button',
            style: TextStyle(fontSize: 24),
          ),
        ),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildStatusBar(), // แถบแสดงสถานะ Wi-Fi และ MQTT
          Expanded(
            child: _users.isEmpty
                ? Center(child: Text('No device, Press + to add device'))
                : ListView.builder(
                    itemCount: _users.length,
                    itemBuilder: (context, index) {
                      final user = _users[index];
                      return Container(
                        margin: EdgeInsets.symmetric(vertical: 10, horizontal: 15),
                        padding: EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.blue, width: 2),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Name: ${user['name']}',
                                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                ),
                                SizedBox(height: 5),
                                Text('ID: ${user['id']}'),
                                Text('Password: ${user['password']}'),
                              ],
                            ),
                            Row(
                              children: [
                                IconButton(
                                  icon: Icon(Icons.play_arrow),
                                  onPressed: () {
                                    String topic = user['id'];
                                    String message = 'Play command for ${user['name']}';
                                    _publishMessage(topic, message);
                                    print('Topic: $topic');
                                    print('Message: $message');
                                  },
                                ),
                                IconButton(
                                  icon: Icon(Icons.access_time),
                                  onPressed: () {
                                    print('Set timer for ${user['name']}');
                                  },
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
          Center(
            child: ElevatedButton(
              onPressed: () {
                showDialog(
                  context: context,
                  builder: (BuildContext context) {
                    return AddUserDialog(onUserAdded: _fetchUsers);
                  },
                );
              },
              child: Icon(Icons.add, size: 30),
              style: ElevatedButton.styleFrom(
                shape: CircleBorder(),
                padding: EdgeInsets.all(20),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatusBar() {
    return Container(
      padding: EdgeInsets.all(10),
      color: Colors.grey[200],
      child: Row(
        children: [
          Row(
            children: [
              Icon(
                _isWifiConnected ? Icons.circle : Icons.circle,
                color: _isWifiConnected ? Colors.green : Colors.red,
              ),
              SizedBox(width: 5),
              Text(
                'Wi-Fi: ${_isWifiConnected ? 'Connected' : 'Disconnected'}',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
          Spacer(),
          Row(
            children: [
              Icon(
                _isMqttConnected ? Icons.circle : Icons.circle,
                color: _isMqttConnected ? Colors.green : Colors.red,
              ),
              SizedBox(width: 5),
              Text(
                'MQTT: ${_isMqttConnected ? 'Connected' : 'Disconnected'}',
                style: TextStyle(fontSize: 16),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class AddUserDialog extends StatefulWidget {
  final Function onUserAdded;

  AddUserDialog({required this.onUserAdded});

  @override
  _AddUserDialogState createState() => _AddUserDialogState();
}

class _AddUserDialogState extends State<AddUserDialog> {
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _nameController = TextEditingController();
  final DatabaseHelper _databaseHelper = DatabaseHelper();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      title: Text(
        'Add',
        style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            decoration: InputDecoration(labelText: 'Name'),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _idController,
            decoration: InputDecoration(labelText: 'ID'),
          ),
          SizedBox(height: 20),
          TextField(
            controller: _passwordController,
            decoration: InputDecoration(labelText: 'Password'),
          ),
          SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              String id = _idController.text;
              String password = _passwordController.text;
              String name = _nameController.text;

              if (id.isNotEmpty && password.isNotEmpty && name.isNotEmpty) {
                await _databaseHelper.insertUser(id, password, name);
                widget.onUserAdded();
                Navigator.of(context).pop();
              }
            },
            child: Text('Apply'),
          ),
        ],
      ),
    );
  }
}
