import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/room_provider.dart';
import '../../user/widgets/room_card.dart';
import 'room_detail_screen.dart';

class RoomFilterScreen extends ConsumerStatefulWidget {
  final Function(Map<String, dynamic>) onFilterChanged;

  const RoomFilterScreen({
    super.key,
    required this.onFilterChanged,
  });

  @override
  ConsumerState<RoomFilterScreen> createState() => _RoomFilterScreenState();
}

class _RoomFilterScreenState extends ConsumerState<RoomFilterScreen> {
  // Use Object.hash to create a unique key for Riverpod family provider
  int _filterKey = 0;
  Map<String, dynamic> _currentFilters = {'status': 'approved'};
  
  final _searchController = TextEditingController();
  final _cityController = TextEditingController();
  final _districtController = TextEditingController();
  final _minPriceController = TextEditingController();
  final _maxPriceController = TextEditingController();
  final _minAreaController = TextEditingController();
  final _maxAreaController = TextEditingController();
  String? _selectedRoomType;
  bool? _allowRoommate;
  bool _showFilters = false;
  
  Timer? _searchDebounceTimer;
  
  final NumberFormat _currencyFormat = NumberFormat.currency(locale: 'vi_VN', symbol: '₫');

  @override
  void initState() {
    super.initState();
    // Apply initial filters on mount
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _applyFilters(silent: true);
    });
  }

  @override
  void dispose() {
    _searchDebounceTimer?.cancel();
    _searchController.dispose();
    _cityController.dispose();
    _districtController.dispose();
    _minPriceController.dispose();
    _maxPriceController.dispose();
    _minAreaController.dispose();
    _maxAreaController.dispose();
    super.dispose();
  }

  int get _activeFiltersCount {
    int count = 0;
    if (_searchController.text.trim().isNotEmpty) count++;
    if (_cityController.text.trim().isNotEmpty) count++;
    if (_districtController.text.trim().isNotEmpty) count++;
    if (_minPriceController.text.trim().isNotEmpty) count++;
    if (_maxPriceController.text.trim().isNotEmpty) count++;
    if (_minAreaController.text.trim().isNotEmpty) count++;
    if (_maxAreaController.text.trim().isNotEmpty) count++;
    if (_selectedRoomType != null) count++;
    if (_allowRoommate != null) count++;
    return count;
  }

  bool get _hasActiveFilters => _activeFiltersCount > 0;

  Map<String, dynamic> _buildFiltersMap() {
    final filters = <String, dynamic>{'status': 'approved'};
    
    final searchText = _searchController.text.trim();
    if (searchText.isNotEmpty) {
      filters['search'] = searchText;
    }
    
    final city = _cityController.text.trim();
    if (city.isNotEmpty) {
      filters['city'] = city;
    }
    
    final district = _districtController.text.trim();
    if (district.isNotEmpty) {
      filters['district'] = district;
    }
    
    final minPriceText = _minPriceController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (minPriceText.isNotEmpty) {
      final price = double.tryParse(minPriceText);
      if (price != null && price > 0) {
        filters['minPrice'] = price;
      }
    }
    
    final maxPriceText = _maxPriceController.text.trim().replaceAll(RegExp(r'[^\d]'), '');
    if (maxPriceText.isNotEmpty) {
      final price = double.tryParse(maxPriceText);
      if (price != null && price > 0) {
        filters['maxPrice'] = price;
      }
    }
    
    final minAreaText = _minAreaController.text.trim();
    if (minAreaText.isNotEmpty) {
      final area = double.tryParse(minAreaText);
      if (area != null && area > 0) {
        filters['minArea'] = area;
      }
    }
    
    final maxAreaText = _maxAreaController.text.trim();
    if (maxAreaText.isNotEmpty) {
      final area = double.tryParse(maxAreaText);
      if (area != null && area > 0) {
        filters['maxArea'] = area;
      }
    }
    
    if (_selectedRoomType != null) {
      filters['roomType'] = _selectedRoomType;
    }
    
    if (_allowRoommate != null) {
      filters['allowRoommate'] = _allowRoommate;
    }
    
    return filters;
  }

  void _applyFilters({bool silent = false}) {
    final newFilters = _buildFiltersMap();
    
    // Check if filters actually changed
    final filtersChanged = _mapEquals(_currentFilters, newFilters) == false;
    
    if (!filtersChanged && !silent) {
      // Show feedback even if filters didn't change
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Bộ lọc đã được áp dụng'),
          duration: Duration(seconds: 1),
        ),
      );
      return;
    }

    setState(() {
      _currentFilters = newFilters;
      _filterKey = Object.hashAll(newFilters.entries.map((e) => '${e.key}:${e.value}'));
    });

    // Notify parent about filter changes
    widget.onFilterChanged(Map<String, dynamic>.from(newFilters));
    
    if (!silent) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_hasActiveFilters 
              ? 'Đã áp dụng $_activeFiltersCount bộ lọc'
              : 'Đã xóa tất cả bộ lọc'),
          duration: const Duration(seconds: 1),
        ),
      );
    }
  }

  bool _mapEquals(Map<String, dynamic> a, Map<String, dynamic> b) {
    if (a.length != b.length) return false;
    for (final key in a.keys) {
      if (!b.containsKey(key) || a[key] != b[key]) {
        return false;
      }
    }
    return true;
  }

  void _clearFilters() {
    setState(() {
      _searchController.clear();
      _cityController.clear();
      _districtController.clear();
      _minPriceController.clear();
      _maxPriceController.clear();
      _minAreaController.clear();
      _maxAreaController.clear();
      _selectedRoomType = null;
      _allowRoommate = null;
      _currentFilters = {'status': 'approved'};
      _filterKey = 0;
    });
    widget.onFilterChanged({'status': 'approved'});
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Đã xóa tất cả bộ lọc'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    // Use the filter key to ensure Riverpod detects changes
    final roomsAsync = ref.watch(roomsProvider(_currentFilters));

    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        title: const Text(
          'Tìm kiếm phòng trọ',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        actions: [
          if (_activeFiltersCount > 0)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: IconButton(
                tooltip: 'Xóa bộ lọc',
                icon: Badge(
                  label: Text('$_activeFiltersCount'),
                  child: const Icon(Icons.filter_alt_outlined),
                ),
                onPressed: _clearFilters,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
              child: Column(
                children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Tìm kiếm theo tên, địa chỉ...',
                    prefixIcon: const Icon(Icons.search),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear),
                            onPressed: () {
                              setState(() {
                                _searchController.clear();
                                _applyFilters();
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    filled: true,
                    fillColor: colorScheme.surface,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  onChanged: (value) {
                    setState(() {});
                    // Debounce search to avoid too many queries
                    _searchDebounceTimer?.cancel();
                    _searchDebounceTimer = Timer(const Duration(milliseconds: 500), () {
                      _applyFilters(silent: true);
                    });
                  },
                ),
                const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () {
                          setState(() => _showFilters = !_showFilters);
                        },
                        icon: Icon(_showFilters ? Icons.expand_less : Icons.expand_more),
                        label: Text(_showFilters ? 'Ẩn bộ lọc' : 'Hiện bộ lọc'),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _applyFilters,
                        icon: const Icon(Icons.search),
                        label: const Text('Tìm kiếm'),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          elevation: 2,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Filter Panel (Expandable)
          if (_showFilters)
            Container(
              constraints: const BoxConstraints(maxHeight: 500),
              decoration: BoxDecoration(
                color: colorScheme.surfaceContainerHighest,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Bộ lọc nâng cao',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (_activeFiltersCount > 0)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primary,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '$_activeFiltersCount bộ lọc',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onPrimary,
                                fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                    // Location Section
                    _buildSectionTitle(context, 'Địa điểm', Icons.location_on_outlined),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _cityController,
                      decoration: InputDecoration(
                        labelText: 'Thành phố',
                        hintText: 'Ví dụ: Hồ Chí Minh, Hà Nội',
                        prefixIcon: const Icon(Icons.location_city_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _districtController,
                      decoration: InputDecoration(
                        labelText: 'Quận/Huyện',
                        hintText: 'Ví dụ: Quận 1, Quận 7',
                        prefixIcon: const Icon(Icons.location_on_outlined),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        filled: true,
                        fillColor: colorScheme.surface,
                      ),
                      onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    // Price Section
                    _buildSectionTitle(context, 'Giá thuê', Icons.attach_money_outlined),
                    const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minPriceController,
                          keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tối thiểu',
                              hintText: '0',
                              prefixIcon: const Icon(Icons.arrow_upward_outlined),
                              suffixText: '₫',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxPriceController,
                          keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tối đa',
                              hintText: 'Không giới hạn',
                              prefixIcon: const Icon(Icons.arrow_downward_outlined),
                              suffixText: '₫',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildQuickFilterChip(
                          context,
                          'Dưới 2 triệu',
                          () {
                            setState(() {
                              _minPriceController.clear();
                              _maxPriceController.text = '2000000';
                            });
                            _applyFilters();
                          },
                        ),
                        _buildQuickFilterChip(
                          context,
                          '2-5 triệu',
                          () {
                            setState(() {
                              _minPriceController.text = '2000000';
                              _maxPriceController.text = '5000000';
                            });
                            _applyFilters();
                          },
                        ),
                        _buildQuickFilterChip(
                          context,
                          '5-10 triệu',
                          () {
                            setState(() {
                              _minPriceController.text = '5000000';
                              _maxPriceController.text = '10000000';
                            });
                            _applyFilters();
                          },
                        ),
                        _buildQuickFilterChip(
                          context,
                          'Trên 10 triệu',
                          () {
                            setState(() {
                              _minPriceController.text = '10000000';
                              _maxPriceController.clear();
                            });
                            _applyFilters();
                          },
                      ),
                    ],
                  ),
                    const SizedBox(height: 24),
                    // Area Section
                    _buildSectionTitle(context, 'Diện tích', Icons.square_foot_outlined),
                    const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _minAreaController,
                          keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tối thiểu',
                              hintText: '0',
                              prefixIcon: const Icon(Icons.arrow_upward_outlined),
                              suffixText: 'm²',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _maxAreaController,
                          keyboardType: TextInputType.number,
                            decoration: InputDecoration(
                              labelText: 'Tối đa',
                              hintText: 'Không giới hạn',
                              prefixIcon: const Icon(Icons.arrow_downward_outlined),
                              suffixText: 'm²',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              filled: true,
                              fillColor: colorScheme.surface,
                            ),
                            onChanged: (_) {
                        setState(() {});
                        // Auto-apply location filters with debounce
                        _searchDebounceTimer?.cancel();
                        _searchDebounceTimer = Timer(const Duration(milliseconds: 800), () {
                          _applyFilters(silent: true);
                        });
                      },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Room Type Section
                    _buildSectionTitle(context, 'Loại phòng', Icons.bed_outlined),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _buildRoomTypeChip(
                          context,
                          'Phòng đơn',
                          'single',
                          Icons.bed_outlined,
                        ),
                        _buildRoomTypeChip(
                          context,
                          'Phòng đôi',
                          'double',
                          Icons.hotel_outlined,
                        ),
                        _buildRoomTypeChip(
                          context,
                          'Phòng chung',
                          'shared',
                          Icons.people_outlined,
                        ),
                        _buildRoomTypeChip(
                          context,
                          'Căn hộ',
                          'apartment',
                          Icons.home_outlined,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    // Allow Roommate Section
                    _buildSectionTitle(context, 'Ở ghép', Icons.people_outlined),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                    children: [
                        FilterChip(
                          label: const Text('Cho phép'),
                        selected: _allowRoommate == true,
                        onSelected: (selected) {
                            setState(() {
                              _allowRoommate = selected ? true : null;
                            });
                            // Auto-apply when roommate filter changes
                            _applyFilters(silent: true);
                          },
                          avatar: Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: _allowRoommate == true
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                        ),
                        FilterChip(
                          label: const Text('Không cho phép'),
                        selected: _allowRoommate == false,
                        onSelected: (selected) {
                            setState(() {
                              _allowRoommate = selected ? false : null;
                            });
                            // Auto-apply when roommate filter changes
                            _applyFilters(silent: true);
                          },
                          avatar: Icon(
                            Icons.cancel_outlined,
                            size: 18,
                            color: _allowRoommate == false
                                ? colorScheme.onPrimaryContainer
                                : colorScheme.onSurfaceVariant,
                          ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                    // Apply Button
                  SizedBox(
                      width: double.infinity,
                    height: 56,
                    child: ElevatedButton.icon(
                      onPressed: _applyFilters,
                      icon: const Icon(Icons.search),
                      label: const Text(
                        'Áp dụng bộ lọc',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Results
          Expanded(
            child: roomsAsync.when(
              data: (rooms) {
                // Show initial state when no filters applied and no results
                if (!_hasActiveFilters && rooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_outlined,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Tìm kiếm phòng trọ',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Nhập từ khóa hoặc sử dụng bộ lọc để tìm phòng trọ phù hợp',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  );
                }
                if (rooms.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer.withOpacity(0.3),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              Icons.search_off_outlined,
                              size: 64,
                              color: colorScheme.primary,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'Không tìm thấy phòng nào',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: colorScheme.onSurface,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Thử điều chỉnh bộ lọc hoặc từ khóa tìm kiếm',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 24),
                          OutlinedButton.icon(
                            onPressed: _clearFilters,
                            icon: const Icon(Icons.clear_all),
                            label: const Text('Xóa tất cả bộ lọc'),
                          ),
                        ],
                      ),
                    ),
                  );
                }
                return Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Tìm thấy ${rooms.length} ${rooms.length == 1 ? 'phòng' : 'phòng'}',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                              color: colorScheme.onSurface,
                            ),
                          ),
                          if (_activeFiltersCount > 0)
                            TextButton.icon(
                              onPressed: _clearFilters,
                              icon: const Icon(Icons.clear_all, size: 18),
                              label: const Text('Xóa bộ lọc'),
                            ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: rooms.length,
                  itemBuilder: (context, index) {
                    final room = rooms[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: RoomCard(
                        room: room,
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => RoomDetailScreen(roomId: room.id),
                            ),
                          );
                        },
                      ),
                    );
                  },
                      ),
                    ),
                  ],
                );
              },
              loading: () => Center(
                child: CircularProgressIndicator(
                  color: colorScheme.primary,
                ),
              ),
              error: (error, stack) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 64,
                        color: colorScheme.error,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Có lỗi xảy ra',
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: colorScheme.error,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        error.toString(),
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 24),
                      ElevatedButton.icon(
                        onPressed: () {
                          setState(() {});
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Thử lại'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 20, color: colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: colorScheme.onSurface,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickFilterChip(BuildContext context, String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      avatar: Icon(Icons.attach_money, size: 16, color: colorScheme.primary),
      backgroundColor: colorScheme.primaryContainer.withOpacity(0.3),
      side: BorderSide(color: colorScheme.primary.withOpacity(0.3)),
    );
  }

  Widget _buildRoomTypeChip(BuildContext context, String label, String value, IconData icon) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isSelected = _selectedRoomType == value;

    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 16,
            color: isSelected
                ? colorScheme.onPrimaryContainer
                : colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: 4),
          Text(label),
        ],
      ),
      selected: isSelected,
                        onSelected: (selected) {
                          setState(() {
                            _selectedRoomType = selected ? value : null;
                          });
                          // Auto-apply when room type changes
                          _applyFilters(silent: true);
                        },
      selectedColor: colorScheme.primaryContainer,
      checkmarkColor: colorScheme.onPrimaryContainer,
      side: BorderSide(
        color: isSelected ? colorScheme.primary : colorScheme.outlineVariant,
      ),
    );
  }
}
