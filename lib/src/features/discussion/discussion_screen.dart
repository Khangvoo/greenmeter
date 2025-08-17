import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:image_picker/image_picker.dart';

class DiscussionScreen extends StatefulWidget {
  const DiscussionScreen({super.key});

  @override
  State<DiscussionScreen> createState() => _DiscussionScreenState();
}

class _DiscussionScreenState extends State<DiscussionScreen> {
  final _messageController = TextEditingController();
  final _currentUser = FirebaseAuth.instance.currentUser;

  Future<void> _sendMessage() async {
    if (_messageController.text.trim().isEmpty) {
      return;
    }

    FocusScope.of(context).unfocus();
    await FirebaseFirestore.instance.collection('discussion').add({
      'text': _messageController.text.trim(),
      'createdAt': Timestamp.now(),
      'userId': _currentUser?.uid,
      'userName': _currentUser?.displayName ?? 'Guest',
      'userImage': _currentUser?.photoURL,
      'imageUrl': null,
    });

    _messageController.clear();
  }

  Future<void> _sendImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile == null) {
      return;
    }

    final file = File(pickedFile.path);
    final ref = FirebaseStorage.instance
        .ref()
        .child('discussion_images')
        .child('${DateTime.now().toIso8601String()}.jpg');

    await ref.putFile(file);
    final imageUrl = await ref.getDownloadURL();

    await FirebaseFirestore.instance.collection('discussion').add({
      'text': null,
      'createdAt': Timestamp.now(),
      'userId': _currentUser?.uid,
      'userName': _currentUser?.displayName ?? 'Guest',
      'userImage': _currentUser?.photoURL,
      'imageUrl': imageUrl,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Thảo luận'),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('discussion')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(child: Text('Chưa có tin nhắn nào.'));
                }

                final messages = snapshot.data!.docs;

                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final message = messages[index];
                    final isMe = message['userId'] == _currentUser?.uid;

                    return MessageBubble(
                      message: message['text'],
                      imageUrl: message['imageUrl'],
                      userName: message['userName'],
                      userImage: message['userImage'],
                      isMe: isMe,
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.image),
                  onPressed: _sendImage,
                ),
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    decoration: const InputDecoration(
                      labelText: 'Gửi tin nhắn...',
                      border: OutlineInputBorder(),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    autocorrect: true,
                    enableSuggestions: true,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class MessageBubble extends StatelessWidget {
  const MessageBubble({
    super.key,
    required this.message,
    required this.imageUrl,
    required this.userName,
    required this.userImage,
    required this.isMe,
  });

  final String? message;
  final String? imageUrl;
  final String userName;
  final String? userImage;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
      children: [
        if (!isMe)
          CircleAvatar(
            backgroundImage: userImage != null ? NetworkImage(userImage!) : null,
            child: userImage == null ? const Icon(Icons.person) : null,
          ),
        Container(
          decoration: BoxDecoration(
            color: isMe ? Colors.grey[300] : Theme.of(context).colorScheme.secondary,
            borderRadius: BorderRadius.circular(12),
          ),
          width: 200,
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
          margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                userName,
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (message != null)
                Text(
                  message!,
                  style: TextStyle(
                    color: isMe ? Colors.black : Colors.white,
                  ),
                ),
              if (imageUrl != null)
                Image.network(
                  imageUrl!,
                  loadingBuilder: (context, child, progress) {
                    return progress == null
                        ? child
                        : const Center(child: CircularProgressIndicator());
                  },
                ),
            ],
          ),
        ),
        if (isMe)
          CircleAvatar(
            backgroundImage: userImage != null ? NetworkImage(userImage!) : null,
            child: userImage == null ? const Icon(Icons.person) : null,
          ),
      ],
    );
  }
}
