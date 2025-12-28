import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/finnhub_service.dart';

class BattleScreen extends StatefulWidget {
  final String battleId;
  const BattleScreen({super.key, required this.battleId});

  @override
  State<BattleScreen> createState() => _BattleScreenState();
}

class _BattleScreenState extends State<BattleScreen> {
  final controller = TextEditingController();
  List<Map<String, dynamic>> results = [];
  List<String> selected = [];

  Future<void> search() async {
    results = await FinnhubService.searchSymbols(controller.text);
    setState(() {});
  }

  Future<void> save() async {
    if (selected.length != 2) return;
    final uid = FirebaseAuth.instance.currentUser!.uid;
    await FirebaseFirestore.instance
        .collection('competitions')
        .doc(widget.battleId)
        .collection('users')
        .doc(uid)
        .update({
      'assets': selected,
      'assetsSelected': true,
    });
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Assets")),
      body: Column(
        children: [
          TextField(controller: controller, onSubmitted: (_) => search()),
          Expanded(
            child: ListView(
              children: results.map((e) {
                final s = e['symbol'];
                return ListTile(
                  title: Text(s),
                  trailing:
                      selected.contains(s) ? const Icon(Icons.check) : null,
                  onTap: () {
                    setState(() {
                      if (selected.contains(s)) {
                        selected.remove(s);
                      } else if (selected.length < 2) {
                        selected.add(s);
                      }
                    });
                  },
                );
              }).toList(),
            ),
          ),
          ElevatedButton(onPressed: save, child: const Text("Confirm"))
        ],
      ),
    );
  }
}
