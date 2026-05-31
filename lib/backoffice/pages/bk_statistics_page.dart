// lib/backoffice/pages/bk_statistics_page.dart
import 'package:flutter/material.dart';

class BkStatisticsPage extends StatelessWidget {
  const BkStatisticsPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: ListView(
        children: const [
          _StatCard(
            title: 'Utenti Registrati',
            value: '-',
            icon: Icons.people,
            color: Colors.blue,
          ),
          _StatCard(
            title: 'Offerte di Lavoro',
            value: '-',
            icon: Icons.work,
            color: Colors.green,
          ),
          _StatCard(
            title: 'Quiz Completati',
            value: '-',
            icon: Icons.quiz,
            color: Colors.orange,
          ),
          _StatCard(
            title: 'Corsi Visualizzati',
            value: '-',
            icon: Icons.play_circle_fill,
            color: Colors.purple,
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 16.0),
      color: const Color(0xFFF5F5F5),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
