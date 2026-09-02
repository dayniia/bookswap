import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:bookswap/core/supabase_client.dart';
import 'package:bookswap/features/auth/auth_provider.dart';

/// Real-time chat screen for a single swap request.
///
/// Both the listing owner and the requester can open this screen
/// from their swap requests list once a request is accepted.
class ChatScreen extends ConsumerStatefulWidget {
  const ChatScreen({
    super.key,
    required this.swapRequestId,
    required this.otherUserName,
    required this.bookTitle,
  });

  final String swapRequestId;
  final String otherUserName;
  final String bookTitle;

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _messages = <Map<String, dynamic>>[];

  bool _loading = true;
  bool _sending = false;
  RealtimeChannel? _channel;
  String? _myId;

  @override
  void initState() {
    super.initState();
    _myId = SupabaseClientProvider.client.auth.currentUser?.id;
    _loadHistory();
    _subscribeRealtime();
  }

  @override
  void dispose() {
    _channel?.unsubscribe();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    super.dispose();
  }

  // ── Load history ──────────────────────────────────────────────────────────

  Future<void> _loadHistory() async {
    try {
      final rows = await SupabaseClientProvider.client
          .from('messages')
          .select('id, content, sender_id, created_at, '
              'profiles(display_name)')
          .eq('swap_request_id', widget.swapRequestId)
          .order('created_at');

      if (mounted) {
        setState(() {
          _messages.addAll(List<Map<String, dynamic>>.from(rows));
          _loading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ── Realtime subscription ─────────────────────────────────────────────────

  void _subscribeRealtime() {
    _channel = SupabaseClientProvider.client
        .channel('messages:${widget.swapRequestId}')
        .onPostgresChanges(
          event: PostgresChangeEvent.insert,
          schema: 'public',
          table: 'messages',
          filter: PostgresChangeFilter(
            type: PostgresChangeFilterType.eq,
            column: 'swap_request_id',
            value: widget.swapRequestId,
          ),
          callback: (payload) async {
            // Fetch the full message row (includes profile join)
            final id = payload.newRecord['id'] as String?;
            if (id == null) return;

            // Avoid duplicates (our own messages are added immediately on send)
            if (_messages.any((m) => m['id'] == id)) return;

            final row = await SupabaseClientProvider.client
                .from('messages')
                .select('id, content, sender_id, created_at, profiles(display_name)')
                .eq('id', id)
                .maybeSingle();

            if (row != null && mounted) {
              setState(() => _messages.add(row));
              _scrollToBottom();
            }
          },
        )
        .subscribe();
  }

  // ── Send message ──────────────────────────────────────────────────────────

  Future<void> _send() async {
    final content = _msgCtrl.text.trim();
    if (content.isEmpty || _sending) return;

    setState(() => _sending = true);
    _msgCtrl.clear();

    try {
      final row = await SupabaseClientProvider.client
          .from('messages')
          .insert({
            'swap_request_id': widget.swapRequestId,
            'sender_id': _myId,
            'content': content,
          })
          .select('id, content, sender_id, created_at, profiles(display_name)')
          .single();

      if (mounted) {
        setState(() => _messages.add(row));
        _scrollToBottom();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send: $e'),
            backgroundColor: Theme.of(context).colorScheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        // Restore text on failure
        _msgCtrl.text = content;
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToBottom() {
    SchedulerBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.otherUserName,
                style: const TextStyle(fontWeight: FontWeight.bold)),
            Text(
              '"${widget.bookTitle}"',
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: colors.onSurfaceVariant),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // ── Message list ─────────────────────────────────────────────
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.chat_bubble_outline_rounded,
                                size: 56,
                                color: colors.onSurfaceVariant
                                    .withValues(alpha: 0.4)),
                            const SizedBox(height: 12),
                            Text('Say hello!',
                                style: theme.textTheme.bodyMedium?.copyWith(
                                    color: colors.onSurfaceVariant)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollCtrl,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        itemCount: _messages.length,
                        itemBuilder: (ctx, i) {
                          final prev = i > 0 ? _messages[i - 1] : null;
                          return _MessageBubble(
                            message: _messages[i],
                            isMe:
                                _messages[i]['sender_id'] == _myId,
                            showAvatar: prev == null ||
                                prev['sender_id'] !=
                                    _messages[i]['sender_id'],
                          );
                        },
                      ),
          ),

          // ── Input bar ────────────────────────────────────────────────
          SafeArea(
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: colors.surface,
                border: Border(
                    top: BorderSide(color: colors.outlineVariant)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _msgCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      minLines: 1,
                      maxLines: 4,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'Message…',
                        filled: true,
                        fillColor: colors.surfaceContainerHighest,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _sending
                      ? const SizedBox(
                          width: 44,
                          height: 44,
                          child: Padding(
                            padding: EdgeInsets.all(10),
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton.filled(
                          onPressed: _send,
                          icon: const Icon(Icons.send_rounded, size: 20),
                          style: IconButton.styleFrom(
                            shape: const CircleBorder(),
                          ),
                        ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Message bubble
// ─────────────────────────────────────────────────────────────────────────────

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.isMe,
    required this.showAvatar,
  });

  final Map<String, dynamic> message;
  final bool isMe;
  final bool showAvatar;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;
    final senderName =
        (message['profiles'] as Map?)?['display_name'] as String? ?? '?';
    final content = message['content'] as String;

    return Padding(
      padding: EdgeInsets.only(
        top: showAvatar ? 8 : 2,
        bottom: 2,
      ),
      child: Row(
        mainAxisAlignment:
            isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          // Other user avatar
          if (!isMe)
            showAvatar
                ? CircleAvatar(
                    radius: 14,
                    backgroundColor: colors.primaryContainer,
                    child: Text(
                      senderName.isNotEmpty ? senderName[0].toUpperCase() : '?',
                      style: TextStyle(
                          fontSize: 11,
                          color: colors.onPrimaryContainer,
                          fontWeight: FontWeight.bold),
                    ),
                  )
                : const SizedBox(width: 28),
          const SizedBox(width: 8),

          // Bubble
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              constraints: BoxConstraints(
                maxWidth: MediaQuery.of(context).size.width * 0.7,
              ),
              decoration: BoxDecoration(
                color: isMe ? colors.primary : colors.surfaceContainerHighest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(18),
                  topRight: const Radius.circular(18),
                  bottomLeft: Radius.circular(isMe ? 18 : 4),
                  bottomRight: Radius.circular(isMe ? 4 : 18),
                ),
              ),
              child: Text(
                content,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: isMe ? colors.onPrimary : colors.onSurface,
                  height: 1.4,
                ),
              ),
            ),
          ),

          if (isMe) const SizedBox(width: 4),
        ],
      ),
    );
  }
}
