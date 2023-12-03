import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyApp());
}

class Task {
  String title;
  bool completed;

  Task(this.title, this.completed);
}

class TaskBloc {
  final _taskController = StreamController<List<Task>>.broadcast();

  List<Task> _tasks = [];

  Stream<List<Task>> get tasksStream => _taskController.stream;

  void addTask(Task task) {
    _tasks.add(task);
    _taskController.sink.add(_tasks);
    addTaskToFirestore(task);
  }

  void toggleTask(int index) {
    _tasks[index].completed = !_tasks[index].completed;
    _taskController.sink.add(_tasks);
    updateTaskInFirestore(_tasks[index], index);
  }

  void editTask(int index, String newTitle) {
    _tasks[index].title = newTitle;
    _taskController.sink.add(_tasks);
    updateTaskInFirestore(_tasks[index], index);
  }

  void deleteTask(int index) {
    _tasks.removeAt(index);
    _taskController.sink.add(_tasks);
    deleteTaskInFirestore(index);
  }

  void dispose() {
    _taskController.close();
  }
}

final bloc = TaskBloc();

void addTaskToFirestore(Task task) {
  FirebaseFirestore.instance.collection('tasks').add({
    'title': task.title,
    'completed': task.completed,
  });
}

void updateTaskInFirestore(Task task, int index) {
  FirebaseFirestore.instance.collection('tasks').doc(index.toString()).update({
    'title': task.title,
    'completed': task.completed,
  });
}

void deleteTaskInFirestore(int index) {
  FirebaseFirestore.instance.collection('tasks').doc(index.toString()).delete();
}

void setupFirebaseMessaging() {
  FirebaseMessaging messaging = FirebaseMessaging.instance;

  messaging.getToken().then((token) {
    print('FCM Token: $token');
  });

  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    setupFirebaseMessaging(); // Llamada para configurar FCM

    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Lista de Tareas'),
        ),
        body: Column(
          children: [
            Expanded(
              child: StreamBuilder<List<Task>>(
                stream: bloc.tasksStream,
                builder: (context, snapshot) {
                  if (!snapshot.hasData || snapshot.data!.isEmpty) {
                    return Center(
                      child: Text('No hay tareas'),
                    );
                  }

                  return ListView.builder(
                    itemCount: snapshot.data!.length,
                    itemBuilder: (context, index) {
                      return TaskWidget(index, snapshot.data![index]);
                    },
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextField(
                onSubmitted: (value) {
                  bloc.addTask(Task(value, false));
                },
                decoration: InputDecoration(
                  hintText: 'Añadir nueva tarea',
                  suffixIcon: Icon(Icons.add),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class TaskWidget extends StatefulWidget {
  final int index;
  final Task task;

  TaskWidget(this.index, this.task);

  @override
  _TaskWidgetState createState() => _TaskWidgetState();
}

class _TaskWidgetState extends State<TaskWidget> {
  TextEditingController _controller = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller.text = widget.task.title;
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      title: widget.task.completed
          ? Text(
              widget.task.title,
              style: TextStyle(decoration: TextDecoration.lineThrough),
            )
          : TextField(
              controller: _controller,
              onSubmitted: (newTitle) {
                bloc.editTask(widget.index, newTitle);
              },
            ),
      leading: Checkbox(
        value: widget.task.completed,
        onChanged: (value) {
          bloc.toggleTask(widget.index);
        },
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: () {
              _controller.text = widget.task.title;
              bloc.editTask(widget.index, _controller.text);
            },
          ),
          IconButton(
            icon: Icon(Icons.delete),
            onPressed: () {
              bloc.deleteTask(widget.index);
            },
          ),
        ],
      ),
    );
  }
}
