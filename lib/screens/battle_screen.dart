import 'dart:async'; // 🔥 UPDATED: needed for debounce

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

  Timer? _debounce; // 🔥 UPDATED: debounce to avoid too many API calls

  // 🔥 UPDATED: search function remains same, just limiting results
  Future<void> search(String query) async {
    if (query.isEmpty) {
      setState(() => results = []);
      return;
    }

    final data = await FinnhubService.searchSymbols(query);

    // 🔥 limit results to 10 for better UX
    results = data.take(10).toList();

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
  void dispose() {
    _debounce?.cancel(); // 🔥 UPDATED: prevent memory leaks
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Select Assets")),
      body: Column(
        children: [

          // 🔥 UPDATED: AUTOCOMPLETE TEXTFIELD
          TextField(
            controller: controller,
            decoration: const InputDecoration(
              hintText: "Search assets (stocks, forex, crypto)",
              prefixIcon: Icon(Icons.search),
              border: OutlineInputBorder(),
            ),

            // 🔥 THIS IS THE MAIN CHANGE
            onChanged: (value) {
              // cancel previous timer
              if (_debounce?.isActive ?? false) {
                _debounce!.cancel();
              }

              // wait 400ms before calling API
              _debounce = Timer(const Duration(milliseconds: 400), () {
                search(value);
              });
            },
          ),

          const SizedBox(height: 10),

          // 🔥 UPDATED: SHOW RESULTS LIVE
          Expanded(
            child: ListView(
              children: results.map((e) {
                final s = e['symbol'];

                return ListTile(
                  title: Text(s),

                  // 🔥 optional: show description if available
                  subtitle: e['description'] != null
                      ? Text(e['description'])
                      : null,

                  trailing: selected.contains(s)
                      ? const Icon(Icons.check)
                      : null,

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

          ElevatedButton(
            onPressed: save,
            child: const Text("Confirm"),
          )
        ],
      ),
    );
  }
}
