import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

import 'battle_screen.dart';
import 'battle_live_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  Timer? _timer;
  Duration _timeLeft = Duration.zero;

  RewardedAd? _rewardedAd;
  final String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';

  // ───────────────── TIMER ─────────────────

  @override
  void initState() {
    super.initState();
    _startUtcTimer();
    _loadRewardedAd();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _rewardedAd?.dispose();
    super.dispose();
  }

  void _startUtcTimer() {
    _updateTimeLeft();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateTimeLeft();
    });
  }

  void _updateTimeLeft() {
    final now = DateTime.now().toUtc();
    final nextHour = DateTime.utc(now.year, now.month, now.day, now.hour + 1);
    if (mounted) {
      setState(() {
        _timeLeft = nextHour.difference(now);
      });
    }
  }

  String _format(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return "$h:$m:$s";
  }

  // ──────────────── BATTLE ID ────────────────

  String _currentBattleId() {
    final nextHour = DateTime.now().toUtc().add(const Duration(hours: 1));
    return "hourly_${nextHour.year}"
        "${nextHour.month.toString().padLeft(2, '0')}"
        "${nextHour.day.toString().padLeft(2, '0')}_"
        "${nextHour.hour.toString().padLeft(2, '0')}";
  }

  // ──────────────── ADS ────────────────

  void _loadRewardedAd() {
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) => _rewardedAd = ad,
        onAdFailedToLoad: (_) => _rewardedAd = null,
      ),
    );
  }

  Future<void> _showRewardedAd() async {
    if (_rewardedAd == null) return;

    _rewardedAd!.show(onUserEarnedReward: (_, __) async {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set({'points': FieldValue.increment(20)}, SetOptions(merge: true));
    });

    _rewardedAd = null;
    _loadRewardedAd();
  }

  // ──────────────── JOIN BATTLE ────────────────

  Future<void> _joinBattle() async {
    final uid = FirebaseAuth.instance.currentUser!.uid;

    final userRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final battleUserRef = FirebaseFirestore.instance
        .collection('competitions')
        .doc(_currentBattleId())
        .collection('users')
        .doc(uid);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final userSnap = await tx.get(userRef);
        final battleSnap = await tx.get(battleUserRef);

        if (battleSnap.exists) {
          throw "You already joined this battle";
        }

        final points = userSnap.data()?['points'] ?? 0;
        if (points < 100) {
          throw "Not enough points";
        }

        tx.update(userRef, {'points': FieldValue.increment(-100)});

        // 🔑 ALWAYS initialize fields
        tx.set(battleUserRef, {
          'assets': [],
          'assetsSelected': false,
          'performance': 0.0,
          'joinedAt': FieldValue.serverTimestamp(),
        });
      });
    } catch (e) {
      _showMsg(e.toString());
    }
  }

  void _showMsg(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ──────────────── UI ────────────────

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final battleUserDoc = FirebaseFirestore.instance
        .collection('competitions')
        .doc(_currentBattleId())
        .collection('users')
        .doc(user.uid);

    return Scaffold(
      appBar: AppBar(
        title: const Text('CashClash'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => FirebaseAuth.instance.signOut(),
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot>(
        stream: userDoc.snapshots(),
        builder: (context, userSnap) {
          final points = userSnap.data?.get('points') ?? 0;

          return StreamBuilder<DocumentSnapshot>(
            stream: battleUserDoc.snapshots(),
            builder: (context, battleSnap) {
              bool joined = false;
              bool assetsSelected = false;

              // ✅ SAFE FIRESTORE ACCESS
              if (battleSnap.hasData && battleSnap.data!.exists) {
                joined = true;
                final data = battleSnap.data!.data() as Map<String, dynamic>;

                if (data.containsKey('assetsSelected')) {
                  assetsSelected = data['assetsSelected'] == true;
                }
              }

              return Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text("Points: $points",
                        style: const TextStyle(
                            fontSize: 28, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 20),
                    Text(
                      _format(_timeLeft),
                      style:
                          const TextStyle(fontSize: 42, fontFamily: 'Courier'),
                    ),
                    const SizedBox(height: 30),
                    if (!joined)
                      ElevatedButton(
                        onPressed: _joinBattle,
                        child: const Text("JOIN BATTLE (100 PTS)"),
                      )
                    else if (!assetsSelected)
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  BattleScreen(battleId: _currentBattleId()),
                            ),
                          );
                        },
                        child: const Text("SELECT ASSETS"),
                      )
                    else
                      ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => BattleLiveScreen(
                                  battleId: _currentBattleId()),
                            ),
                          );
                        },
                        child: const Text("GO TO LIVE BATTLE"),
                      ),
                    const SizedBox(height: 20),
                    TextButton(
                      onPressed: _showRewardedAd,
                      child: const Text("Watch Ad (+20 Points)"),
                    ),
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}
