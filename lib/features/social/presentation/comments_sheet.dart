import 'package:flutter/material.dart';

import '../../../core/config/supabase_config.dart';
import '../../../core/theme/app_theme.dart';
import '../data/social_repository.dart';

class CommentsSheet extends StatefulWidget {
  const CommentsSheet({
    super.key,
    required this.activityId,
    required this.onCountChanged,
  });

  final String activityId;
  final ValueChanged<int> onCountChanged;

  static Future<void> show(
    BuildContext context, {
    required String activityId,
    required ValueChanged<int> onCountChanged,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: AppColors.card,
      builder: (context) => CommentsSheet(
        activityId: activityId,
        onCountChanged: onCountChanged,
      ),
    );
  }

  @override
  State<CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<CommentsSheet> {
  final _controller = TextEditingController();
  List<CommentItem> _comments = const [];
  bool _loading = true;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final client = SupabaseService.client;
    if (client == null) {
      setState(() => _loading = false);
      return;
    }
    try {
      final comments =
          await SocialRepository(client).fetchComments(widget.activityId);
      if (!mounted) return;
      setState(() {
        _comments = comments;
        _loading = false;
      });
      widget.onCountChanged(comments.length);
    } catch (_) {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  Future<void> _send() async {
    final client = SupabaseService.client;
    if (client == null) return;
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    setState(() => _sending = true);
    try {
      final comment = await SocialRepository(client).addComment(
        activityId: widget.activityId,
        body: text,
      );
      if (!mounted) return;
      setState(() {
        _comments = [..._comments, comment];
        _controller.clear();
        _sending = false;
      });
      widget.onCountChanged(_comments.length);
    } catch (error) {
      if (!mounted) return;
      setState(() => _sending = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString())),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;

    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(20, 4, 20, 12),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Yorumlar',
                  style: TextStyle(
                    color: AppColors.ink,
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _comments.isEmpty
                      ? Center(
                          child: Text(
                            'İlk yorumu sen yaz.',
                            style: TextStyle(color: AppColors.mutedInk),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _comments.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final comment = _comments[index];
                            return Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundColor: AppColors.softGreen,
                                  child: Text(
                                    comment.userName.isNotEmpty
                                        ? comment.userName[0].toUpperCase()
                                        : 'R',
                                    style: TextStyle(
                                      color: AppColors.primaryDark,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        comment.userName,
                                        style: TextStyle(
                                          color: AppColors.ink,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 13,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        comment.body,
                                        style: TextStyle(
                                          color: AppColors.ink,
                                          fontSize: 13,
                                          height: 1.35,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
            ),
            SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _controller,
                        decoration: const InputDecoration(
                          hintText: 'Yorum yaz...',
                        ),
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filled(
                      onPressed: _sending ? null : _send,
                      style: IconButton.styleFrom(
                        backgroundColor: AppColors.primaryDark,
                      ),
                      icon: _sending
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
