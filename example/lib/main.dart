import 'package:flutter/material.dart';
import 'package:roadway_native_navigation/roadway_native_navigation.dart';

void main() => runApp(const ExampleApp());

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(home: ExampleHome());
  }
}

class ExampleHome extends StatefulWidget {
  const ExampleHome({super.key});

  @override
  State<ExampleHome> createState() => _ExampleHomeState();
}

class _ExampleHomeState extends State<ExampleHome> {
  int _selectedIndex = 0;
  int _actions = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 80, 16, 140),
        itemCount: 20,
        itemBuilder: (BuildContext context, int index) => Container(
          height: 90,
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: Colors.primaries[index % Colors.primaries.length],
            borderRadius: BorderRadius.circular(16),
          ),
          alignment: Alignment.center,
          child: Text(
            'Tab $_selectedIndex · item $index · actions $_actions',
            style: const TextStyle(color: Colors.white, fontSize: 18),
          ),
        ),
      ),
      bottomNavigationBar: NativeNavigationBar(
        items: const <NativeNavigationItem>[
          NativeNavigationItem(
            label: 'Inicio',
            icon: NativeNavigationIcon.home,
          ),
          NativeNavigationItem(
            label: 'Gráficas',
            icon: NativeNavigationIcon.chart,
          ),
          NativeNavigationItem(
            label: 'Compartido',
            icon: NativeNavigationIcon.group,
          ),
          NativeNavigationItem(
            label: 'Menú',
            icon: NativeNavigationIcon.profile,
          ),
        ],
        selectedIndex: _selectedIndex,
        onItemSelected: (int index) => setState(() => _selectedIndex = index),
        action: const NativeNavigationAction(
          label: 'Nuevo gasto',
          icon: NativeNavigationIcon.add,
          color: Color(0xFF2CA3F3),
        ),
        onActionPressed: () => setState(() => _actions++),
      ),
    );
  }
}
