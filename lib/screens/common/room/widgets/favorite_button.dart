import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../services/firestore_service.dart';

class FavoriteButtonState extends ConsumerState<FavoriteButton> {
  bool? _isSaved;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadSavedStatus();
  }

  Future<void> _loadSavedStatus() async {
    final isSaved = await FirestoreService().isRoomSaved(widget.userId, widget.roomId);
    if (mounted) {
      setState(() => _isSaved = isSaved);
    }
  }

  Future<void> _toggleFavorite() async {
    if (_isLoading) return;
    
    setState(() => _isLoading = true);
    
    final firestoreService = FirestoreService();
    final wasSaved = _isSaved ?? false;
    
    try {
      if (wasSaved) {
        await firestoreService.unsaveRoom(widget.userId, widget.roomId);
      } else {
        await firestoreService.saveRoom(widget.userId, widget.roomId);
      }
      
      if (mounted) {
        setState(() {
          _isSaved = !wasSaved;
          _isLoading = false;
        });
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(wasSaved ? 'Đã bỏ lưu phòng' : 'Đã lưu phòng'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Lỗi: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isSaved == null) {
      return const SizedBox.shrink();
    }
    
    return IconButton(
      icon: _isLoading
          ? SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  _isSaved! ? Colors.red : Colors.white,
                ),
              ),
            )
          : Icon(
              _isSaved! ? Icons.favorite : Icons.favorite_border,
              color: _isSaved! ? Colors.red : Colors.white,
            ),
      onPressed: _isLoading ? null : _toggleFavorite,
      tooltip: _isSaved! ? 'Bỏ lưu' : 'Lưu phòng',
    );
  }
}

class FavoriteButton extends ConsumerStatefulWidget {
  final String userId;
  final String roomId;

  const FavoriteButton({
    super.key,
    required this.userId,
    required this.roomId,
  });

  @override
  ConsumerState<FavoriteButton> createState() => FavoriteButtonState();
}

