import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:google_fonts/google_fonts.dart';

import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const TeamScoreTrackerApp());
}

class TeamScoreTrackerApp extends StatelessWidget {
  const TeamScoreTrackerApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ITC Debug & Develop',
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.indigoAccent,
          elevation: 0,
        ),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const TeamScorePage(),
    );
  }
}

class Team {
  final String id;
  String name;
  int score;
  String? imageUrl;

  Team({
    required this.id,
    required this.name,
    required this.score,
    this.imageUrl,
  });

  factory Team.fromDoc(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final rawScore = data['score'] as num?;
    return Team(
      id: doc.id,
      name: data['name'] as String? ?? doc.id,
      score: rawScore?.toInt() ?? 0,
      imageUrl: (data['imageUrl'] as String?)?.isNotEmpty == true
          ? data['imageUrl'] as String
          : null,
    );
  }
}

class TeamScorePage extends StatefulWidget {
  const TeamScorePage({Key? key}) : super(key: key);

  @override
  State<TeamScorePage> createState() => _TeamScorePageState();
}

class _TeamScorePageState extends State<TeamScorePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instanceFor(
    app: Firebase.app(),
    databaseId: 'itcfsktm',
  );

  // track per‑team upload progress (0.0 → 1.0)
  final Map<String, double> _uploadProgress = {};

  // Gradient colors for cards
  final List<List<Color>> _gradients = [
    [Colors.redAccent, Colors.deepOrangeAccent],
    [Colors.greenAccent, Colors.tealAccent],
    [Colors.blueAccent, Colors.lightBlueAccent],
    [Colors.pinkAccent, Colors.pinkAccent],
    [Colors.purpleAccent, Colors.deepPurpleAccent],
    [Colors.orangeAccent, Colors.deepOrange],
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            bottom: Radius.circular(24),
          ),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF4A00E0), Color(0xFF8E2DE2)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
        ),
        title: Text(
          'ITC Debug & Develop',
          style: GoogleFonts.poppins(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: Colors.white,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('teams').snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError)
            return Center(child: Text('Error: ${snapshot.error}'));
          if (!snapshot.hasData)
            return const Center(child: CircularProgressIndicator());

          final docs = snapshot.data!.docs;
          if (docs.isEmpty)
            return const Center(child: Text('No teams configured in Firestore'));

          // map and limit to first 5 teams
          final teams = docs.map((d) => Team.fromDoc(d)).toList();
          final displayTeams = teams.length > 5 ? teams.sublist(0, 5) : teams;

          return GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.8,
            ),
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 12),
            itemCount: displayTeams.length,
            itemBuilder: (context, i) => _buildTeamCard(displayTeams[i], i),
          );
        },
      ),
    );
  }

  Widget _buildTeamCard(Team team, int index) {
    final colors = _gradients[index % _gradients.length];
    final isUploading = _uploadProgress.containsKey(team.id);
    final progress = _uploadProgress[team.id] ?? 0.0;
    final percent = (progress * 100).clamp(0, 100).toInt();

    return KeyedSubtree(
      key: ValueKey(team.id),
      child: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          gradient: LinearGradient(
            colors: colors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          border: Border.all(color: colors.first, width: 3),
          boxShadow: [
            BoxShadow(
              color: colors.last.withOpacity(0.6),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: Stack(
            children: [
              if (team.imageUrl != null)
                Positioned.fill(
                  child: Image.network(
                    team.imageUrl!,
                    key: ValueKey(team.imageUrl),
                    fit: BoxFit.cover,
                  ),
                ),

              // dark overlay
              Container(color: Colors.black.withOpacity(0.2)),

              // team name banner at top
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                  decoration: BoxDecoration(
                    color: colors.first.withOpacity(0.8),
                    borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(24)),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(
                    team.name,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),

              // bubble‑style upload spinner + percentage
              if (isUploading)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withOpacity(0.5),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        CupertinoActivityIndicator(radius: 20),
                        const SizedBox(height: 8),
                        Text(
                          '$percent%',
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

              // card content (score + buttons)
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 12),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const SizedBox(height: 40), // spacer for banner

                    // score display
                    Text(
                      '${team.score}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    // +/- buttons with color and shadow
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: colors.first,
                            shadowColor: colors.last,
                            elevation: 6,
                          ),
                          onPressed: team.score > 0
                              ? () => _updateScore(team, -1)
                              : null,
                          child: const Icon(Icons.remove, color: Colors.white),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            shape: const CircleBorder(),
                            padding: const EdgeInsets.all(12),
                            backgroundColor: colors.first,
                            shadowColor: colors.last,
                            elevation: 6,
                          ),
                          onPressed: () => _updateScore(team, 1),
                          child: const Icon(Icons.add, color: Colors.white),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // top row: image picker & rename
              Positioned(
                top: 50,
                left: 8,
                right: 8,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => _pickAndUploadImage(team),
                      icon: const Icon(Icons.camera_alt),
                      color: Colors.white,
                      iconSize: 28,
                    ),
                    IconButton(
                      onPressed: () => _showRenameDialog(team),
                      icon: const Icon(Icons.edit),
                      color: Colors.white,
                      iconSize: 24,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickAndUploadImage(Team team) async {
    final result = await FilePicker.platform
        .pickFiles(type: FileType.image, withData: true);
    if (result == null || result.files.isEmpty) return;

    final file = result.files.first;
    final data = file.bytes!;
    final ext = file.extension ?? 'png';
    final ts = DateTime.now().millisecondsSinceEpoch;
    final path = 'team_images/${team.id}_$ts.$ext';
    final ref = FirebaseStorage.instance.ref(path);

    // start upload & track progress
    final uploadTask = ref.putData(data);
    _uploadProgress[team.id] = 0.0;
    setState(() {});

    uploadTask.snapshotEvents.listen((snap) {
      final prog = snap.bytesTransferred / snap.totalBytes;
      _uploadProgress[team.id] = prog;
      setState(() {});
    });

    try {
      await uploadTask;
      final url = await ref.getDownloadURL();
      await _firestore.collection('teams').doc(team.id).update({'imageUrl': url});
    } finally {
      _uploadProgress.remove(team.id);
      setState(() {});
    }
  }

  Future<void> _updateScore(Team team, int delta) async {
    final newScore = (team.score + delta).clamp(0, double.infinity).toInt();
    await _firestore.collection('teams').doc(team.id).update({'score': newScore});
  }

  Future<void> _showRenameDialog(Team team) async {
    final controller = TextEditingController(text: team.name);
    final result = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Rename Team'),
        content: TextField(controller: controller),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text('Save')),
        ],
      ),
    );
    if (result != null && result.trim().isNotEmpty) {
      await _firestore.collection('teams').doc(team.id).update({'name': result.trim()});
    }
  }
}