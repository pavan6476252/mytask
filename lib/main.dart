import 'package:timezone/timezone.dart' as tz;
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MaterialApp(
    debugShowCheckedModeBanner: false,
    theme: ThemeData(useMaterial3: true, brightness: Brightness.dark),
    title: 'Task Manager',
    home: HomePage(),
  ));
}

class Task {
  String title;
  String description;
  DateTime dueDate;
  int priority;
  bool notificationsEnabled;

  String id;

  Task({
    required this.title,
    required this.description,
    required this.dueDate,
    required this.priority,
    required this.notificationsEnabled,
    required this.id,
  });

  Map<String, dynamic> toMap() {
    return <String, dynamic>{
      'title': title,
      'description': description,
      'dueDate': dueDate.millisecondsSinceEpoch,
      'priority': priority,
      'notificationsEnabled': notificationsEnabled,
    };
  }

  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      title: map['title'] as String,
      description: map['description'] as String,
      dueDate: DateTime.fromMillisecondsSinceEpoch(map['dueDate'] as int),
      priority: map['priority'] as int,
      notificationsEnabled: map['notificationsEnabled'] as bool,
      id: '',
    );
  }

  String toJson() => json.encode(toMap());

  factory Task.fromJson(String source) =>
      Task.fromMap(json.decode(source) as Map<String, dynamic>);
}

class HomePage extends StatefulWidget {
  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Task> _tasks = [];
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  @override
  void initState() {
    _loadTasks();

    var initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    var initializationSettingsIOS = IOSInitializationSettings();
    var initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid, iOS: initializationSettingsIOS);
    flutterLocalNotificationsPlugin.initialize(initializationSettings);

    super.initState();
  }

  Future<void> _showNotification(String title, String body) async {
    var androidPlatformChannelSpecifics = AndroidNotificationDetails(
        'channel_id', 'channel_name',
        importance: Importance.max, priority: Priority.high, ticker: 'ticker');
    var iOSPlatformChannelSpecifics = IOSNotificationDetails();
    var platformChannelSpecifics = NotificationDetails(
        android: androidPlatformChannelSpecifics,
        iOS: iOSPlatformChannelSpecifics);
    await flutterLocalNotificationsPlugin
        .show(0, title, body, platformChannelSpecifics, payload: 'item x');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Task Manager'),
      ),
      body: _tasks.isEmpty
          ? const Center(child: Text('No tasks yet!'))
          : Padding(
              padding: const EdgeInsets.all(5.0),
              child: ListView.builder(
                itemCount: _tasks.length,
                itemBuilder: (context, index) {
                  final task = _tasks[index];
                  return Card(
                    shape: RoundedRectangleBorder(
                      side: BorderSide(
                        color: task.priority == 5
                            ? Colors.red
                            : task.priority >= 3
                                ? Colors.amber
                                : Colors.green,
                      ),
                      borderRadius: BorderRadius.circular(20.0),
                    ),
                    child: Dismissible(
                      key: Key(task.id),
                      direction: DismissDirection.endToStart,
                      background: Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(20.0),
                          color: const Color.fromARGB(255, 253, 105, 82),
                        ),
                        child: const Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.all(8.0),
                            child: Icon(Icons.delete, color: Colors.white),
                          ),
                        ),
                      ),
                      onDismissed: (_) {
                        _removeTask(index);
                      },
                      child: ListTile(
                        title: Text(task.title),
                        subtitle: Text(task.description),
                        trailing: Text(
                          '${task.priority}',
                          style: TextStyle(
                            color: task.priority == 5
                                ? Colors.red
                                : task.priority >= 3
                                    ? Colors.amber
                                    : Colors.green,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        onTap: () async {
                          final updatedTask =
                              await Navigator.of(context).push<Task>(
                            MaterialPageRoute(
                              builder: (context) => TaskForm(task: task),
                            ),
                          );
                          _updateTask(index, updatedTask!);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTask = await Navigator.of(context).push<Task?>(
            MaterialPageRoute(
              builder: (context) => TaskForm(),
            ),
          );
          if (newTask != null) {
            _addTask(newTask);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  void _addTask(Task task) async {
    setState(() {
      _tasks.add(task);
    });
    final prefs = await SharedPreferences.getInstance();
    final taskList = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString('tasks', taskList.toString());

    if (task.dueDate != null) {
      var scheduledNotificationDateTime = task.dueDate;
      var androidPlatformChannelSpecifics = AndroidNotificationDetails(
          'channel_id', 'channel_name',
          importance: Importance.max,
          priority: Priority.high,
          ticker: 'ticker');
      var iOSPlatformChannelSpecifics = IOSNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics);
      flutterLocalNotificationsPlugin.schedule(0, task.title, task.description,
          scheduledNotificationDateTime, platformChannelSpecifics);
    }
  }

  void _removeTask(int index) async {
    setState(() {
      _tasks.removeAt(index);
    });
    final prefs = await SharedPreferences.getInstance();
    final taskList = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString('tasks', taskList.toString());
  }

  void _updateTask(int index, Task task) async {
    setState(() {
      _tasks[index] = task;
    });
    final prefs = await SharedPreferences.getInstance();
    final taskList = _tasks.map((t) => t.toJson()).toList();
    await prefs.setString('tasks', taskList.toString());
    if (task.dueDate != null) {
      var scheduledNotificationDateTime = task.dueDate;
      var androidPlatformChannelSpecifics =
          AndroidNotificationDetails('channel_id', "description");
      var iOSPlatformChannelSpecifics = IOSNotificationDetails();
      var platformChannelSpecifics = NotificationDetails(
          android: androidPlatformChannelSpecifics,
          iOS: iOSPlatformChannelSpecifics);
      flutterLocalNotificationsPlugin.zonedSchedule(
          0,
          task.title,
          task.description,
          tz.TZDateTime.from(scheduledNotificationDateTime, tz.local),
          platformChannelSpecifics,
          androidAllowWhileIdle: true,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          matchDateTimeComponents: DateTimeComponents.time);
    } else {
      flutterLocalNotificationsPlugin.cancel(index);
    }
  }

  Future<void> _loadTasks() async {
    final prefs = await SharedPreferences.getInstance();
    final taskListString = prefs.getString('tasks');
    if (taskListString != null) {
      final taskListJson = jsonDecode(taskListString) as List<dynamic>; 

      
       for (var element in taskListJson) {
        _tasks.add(Task.fromMap(element));
      }
      setState(() {
        
      });
    }
  }
}

class TaskList extends StatefulWidget {
  final List<Task> tasks;

  TaskList({Key? key, required this.tasks}) : super(key: key);

  @override
  _TaskListState createState() => _TaskListState();
}

class _TaskListState extends State<TaskList> {
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: widget.tasks.length,
      itemBuilder: (context, index) {
        final task = widget.tasks[index];
        return Card(
          child: ListTile(
            title: Text(task.title),
            subtitle: Text(DateFormat.yMd().add_jm().format(task.dueDate)),
            trailing: IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () async {
                final editedTask = await Navigator.of(context).push<Task?>(
                  MaterialPageRoute(
                    builder: (context) => TaskForm(task: task),
                  ),
                );
                if (editedTask != null) {
                  setState(() {
                    widget.tasks[index] = editedTask;
                  });
                }
              },
            ),
            onLongPress: () {
              showDialog(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Delete Task'),
                  content:
                      const Text('Are you sure you want to delete this task?'),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() {
                          widget.tasks.removeAt(index);
                        });
                        Navigator.of(context).pop();
                      },
                      child: const Text('Delete'),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class TaskForm extends StatefulWidget {
  final Task? task;

  TaskForm({Key? key, this.task}) : super(key: key);

  @override
  _TaskFormState createState() => _TaskFormState();
}

class _TaskFormState extends State<TaskForm> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _titleController;
  late TextEditingController _descriptionController;
  late DateTime _dueDate;
  late int _priority;
  late bool _notificationsEnabled;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task?.title ?? '');
    _descriptionController =
        TextEditingController(text: widget.task?.description ?? '');
    _dueDate = widget.task?.dueDate ?? DateTime.now();
    _priority = widget.task?.priority ?? 1;
    _notificationsEnabled = widget.task?.notificationsEnabled ?? true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.task == null ? 'Add Task' : 'Edit Task'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(5.0),
        child: Form(
          key: _formKey,
          child: Card(
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  TextFormField(
                    controller: _descriptionController,
                    decoration: const InputDecoration(
                      labelText: 'Description',
                    ),
                  ),
                  Card(
                    child: ListTile(
                      title: const Text('Due Date'),
                      trailing:
                          Text(DateFormat.yMd().add_jm().format(_dueDate)),
                      onTap: () async {
                        final selectedDate = await showDatePicker(
                          context: context,
                          initialDate: _dueDate,
                          firstDate: DateTime.now(),
                          lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                        );
                        if (selectedDate != null) {
                          final selectedTime = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_dueDate),
                          );
                          if (selectedTime != null) {
                            setState(() {
                              _dueDate = DateTime(
                                selectedDate.year,
                                selectedDate.month,
                                selectedDate.day,
                                selectedTime.hour,
                                selectedTime.minute,
                              );
                            });
                          }
                        }
                      },
                    ),
                  ),
                  DropdownButtonFormField<int>(
                    value: _priority,
                    decoration: const InputDecoration(
                      labelText: 'Priority',
                    ),
                    items: [1, 2, 3, 4, 5]
                        .map((e) => DropdownMenuItem<int>(
                              value: e,
                              child: Text(e.toString()),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _priority = value!;
                      });
                    },
                  ),
                  SwitchListTile(
                    title: const Text('Notifications'),
                    value: _notificationsEnabled,
                    onChanged: (value) {
                      setState(() {
                        _notificationsEnabled = value;
                      });
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: OutlinedButton(
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            final task = Task(
                              title: _titleController.text,
                              description: _descriptionController.text,
                              dueDate: _dueDate,
                              priority: _priority,
                              notificationsEnabled: _notificationsEnabled,
                              id: _titleController.text +
                                  _descriptionController.text +
                                  _priority.toString(),
                            );
                            Navigator.of(context).pop(task);
                          }
                        },
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.watch_later_outlined),
                            const Text('  Save'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
