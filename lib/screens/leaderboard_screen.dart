import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class LeaderboardScreen extends StatelessWidget {
  final String battleId;
  const LeaderboardScreen({super.key, required this.battleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Leaderboard")),
      body: StreamBuilder(
        stream: FirebaseFirestore.instance
            .collection('competitions')
            .doc(battleId)
            .collection('users')
            .orderBy('performance', descending: true)
            .snapshots(),
        builder: (_, snap) {
          if (!snap.hasData) return const CircularProgressIndicator();
          return ListView(
            children: snap.data!.docs
                .map((d) => ListTile(
                      title: Text(d.id),
                      trailing: Text("${(d['performance'] ?? 0).toString()}%"),
                    ))
                .toList(),
          );
        },
      ),
    );
  }
}
