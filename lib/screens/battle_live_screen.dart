import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../services/finnhub_service.dart';

class BattleLiveScreen extends StatefulWidget {
  final String battleId;
  const BattleLiveScreen({super.key, required this.battleId});

  @override
  State<BattleLiveScreen> createState() => _BattleLiveScreenState();
}

class _BattleLiveScreenState extends State<BattleLiveScreen> {
  List<String> assets = [];
  Map<String, double> prices = {};
  Timer? timer;

  @override
  void initState() {
    super.initState();
    load();
  }

  Future<void> load() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final doc = await FirebaseFirestore.instance
        .collection('competitions')
        .doc(widget.battleId)
        .collection('users')
        .doc(uid)
        .get();
    assets = List<String>.from(doc['assets']);
    fetch();
    timer = Timer.periodic(const Duration(seconds: 10), (_) => fetch());
    setState(() {});
  }

  Future<void> fetch() async {
    for (final a in assets) {
      prices[a] = await FinnhubService.getPrice(a);
    }
    setState(() {});
  }

  @override
  void dispose() {
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Live Battle")),
      body: ListView(
        children: assets
            .map((a) => ListTile(
                  title: Text(a),
                  trailing: Text(prices[a]?.toStringAsFixed(2) ?? "..."),
                ))
            .toList(),
      ),
    );
  }
}
