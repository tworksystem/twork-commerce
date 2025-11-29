import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:ecommerce_int2/providers/point_provider.dart';
import 'package:ecommerce_int2/providers/auth_provider.dart';
import 'package:ecommerce_int2/models/point_transaction.dart';
import 'package:ecommerce_int2/app_properties.dart';
import 'package:ecommerce_int2/services/point_service.dart';
import 'package:intl/intl.dart';

class PointHistoryPage extends StatefulWidget {
  const PointHistoryPage({super.key});

  @override
  _PointHistoryPageState createState() => _PointHistoryPageState();
}

class _PointHistoryPageState extends State<PointHistoryPage> {
  PointTransactionType? _selectedFilter;
  List<PointTransaction> _expiringSoon = [];
  DateTimeRange? _selectedDateRange;

  @override
  void initState() {
    super.initState();
    // Load point balance and transactions when page opens
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadPoints();
    });
  }

  Future<void> _loadPoints() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final pointProvider = Provider.of<PointProvider>(context, listen: false);

    if (authProvider.isAuthenticated && authProvider.user != null) {
      final userId = authProvider.user!.id.toString();
      await pointProvider.loadBalance(userId);
      await pointProvider.loadTransactions(userId);
      
      // Check for expired points
      await PointService.checkAndMarkExpiredPoints(userId);
      
      // Load expiring soon points
      final expiring = await PointService.getPointsExpiringSoon(userId);
      setState(() {
        _expiringSoon = expiring;
      });
      
      // Reload balance after expiration check
      await pointProvider.loadBalance(userId);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0.0,
        iconTheme: IconThemeData(color: darkGrey),
        title: Text(
          'Point History',
          style: TextStyle(
            color: darkGrey,
            fontWeight: FontWeight.w500,
            fontSize: 18.0,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.insights_outlined, color: darkGrey),
            tooltip: 'Analytics',
            onPressed: () {
              final transactions =
                  Provider.of<PointProvider>(context, listen: false)
                      .transactions;
              _showAnalytics(context, transactions);
            },
          ),
        ],
      ),
      body: Consumer2<PointProvider, AuthProvider>(
        builder: (context, pointProvider, authProvider, child) {
          if (!authProvider.isAuthenticated || authProvider.user == null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.lock_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'Please login to view your points',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            );
          }

          if (pointProvider.isLoading) {
            return Center(
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(mediumYellow),
              ),
            );
          }

          final balance = pointProvider.balance;
          final transactions = pointProvider.transactions;

          return Column(
            children: [
              // Expiration warning banner
              if (_expiringSoon.isNotEmpty)
                Container(
                  margin: EdgeInsets.all(16),
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.orange[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange[300]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Points Expiring Soon!',
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                                color: Colors.orange[900],
                              ),
                            ),
                            Text(
                              'You have ${_expiringSoon.length} transaction(s) expiring within 30 days',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.orange[800],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

              // Point balance card
              Container(
                margin: EdgeInsets.all(16),
                padding: EdgeInsets.all(24),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [mediumYellow, darkYellow],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: mediumYellow.withOpacity(0.3),
                      blurRadius: 12,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          balance?.tier.icon ?? '',
                          style: TextStyle(fontSize: 24),
                        ),
                        SizedBox(width: 8),
                        Text(
                          balance?.tier.name ?? 'Basic',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Your Points',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      balance?.formattedBalance ?? '0 points',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (balance != null) ...[
                      SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildStatItem(
                            'Lifetime Earned',
                            '${balance.lifetimeEarned}',
                            Colors.white70,
                          ),
                          _buildStatItem(
                            'Lifetime Redeemed',
                            '${balance.lifetimeRedeemed}',
                            Colors.white70,
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),

              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
                child: Row(
                  children: [
                    OutlinedButton.icon(
                      icon: Icon(Icons.calendar_today_outlined,
                          size: 16, color: darkGrey),
                      label: Text(
                        _selectedDateRange == null
                            ? 'Date range'
                            : '${DateFormat.MMMd().format(_selectedDateRange!.start)} - ${DateFormat.MMMd().format(_selectedDateRange!.end)}',
                        style: TextStyle(color: darkGrey),
                      ),
                      onPressed: _pickDateRange,
                      style: OutlinedButton.styleFrom(
                        foregroundColor: darkGrey,
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                    ),
                    if (_selectedDateRange != null) ...[
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _selectedDateRange = null;
                          });
                        },
                        child: const Text('Clear'),
                      ),
                    ],
                  ],
                ),
              ),

              // Filter chips
              Container(
                height: 50,
                padding: EdgeInsets.symmetric(horizontal: 16),
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    _buildFilterChip(null, 'All'),
                    _buildFilterChip(PointTransactionType.earn, 'Earned'),
                    _buildFilterChip(PointTransactionType.redeem, 'Redeemed'),
                    _buildFilterChip(PointTransactionType.referral, 'Referral'),
                    _buildFilterChip(PointTransactionType.birthday, 'Birthday'),
                  ],
                ),
              ),

              // Transactions list
              Expanded(
                child: transactions.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history,
                              size: 64,
                              color: Colors.grey[400],
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No point transactions yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start earning points by making purchases!',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                            ),
                          ],
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadPoints,
                        color: mediumYellow,
                        child: ListView.builder(
                          padding: EdgeInsets.symmetric(horizontal: 16),
                          itemCount: _getFilteredTransactions(transactions).length,
                          itemBuilder: (context, index) {
                            final transaction = _getFilteredTransactions(transactions)[index];
                            return _buildTransactionCard(transaction);
                          },
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 12,
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(PointTransactionType? type, String label) {
    final isSelected = _selectedFilter == type;
    return Padding(
      padding: EdgeInsets.only(right: 8),
      child: FilterChip(
        label: Text(label),
        selected: isSelected,
        onSelected: (selected) {
          setState(() {
            _selectedFilter = selected ? type : null;
          });
        },
        selectedColor: mediumYellow,
        checkmarkColor: Colors.white,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : darkGrey,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  List<PointTransaction> _getFilteredTransactions(
      List<PointTransaction> transactions) {
    Iterable<PointTransaction> filtered = transactions;

    if (_selectedFilter != null) {
      filtered = filtered.where((t) => t.type == _selectedFilter);
    }

    if (_selectedDateRange != null) {
      final start = DateTime(
        _selectedDateRange!.start.year,
        _selectedDateRange!.start.month,
        _selectedDateRange!.start.day,
      );
      final end = DateTime(
        _selectedDateRange!.end.year,
        _selectedDateRange!.end.month,
        _selectedDateRange!.end.day,
        23,
        59,
        59,
      );
      filtered = filtered.where(
        (t) => !t.createdAt.isBefore(start) && !t.createdAt.isAfter(end),
      );
    }

    return filtered.toList();
  }

  Widget _buildTransactionCard(PointTransaction transaction) {
    final color = _getTransactionColor(transaction.type);
    final icon = _getTransactionIcon(transaction.type);
    final isExpiringSoon = transaction.isExpiringSoon;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: isExpiringSoon ? Border.all(color: Colors.orange[300]!, width: 2) : null,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: color,
              size: 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.description ?? _getDefaultDescription(transaction.type),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: darkGrey,
                        ),
                      ),
                    ),
                    if (isExpiringSoon)
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.orange[100],
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'Expiring',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange[900],
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 4),
                Text(
                  _formatDate(transaction.createdAt),
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
                if (transaction.orderId != null) ...[
                  SizedBox(height: 4),
                  Text(
                    'Order #${transaction.orderId}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
                if (transaction.expiresAt != null && !transaction.expired) ...[
                  SizedBox(height: 4),
                  Text(
                    'Expires: ${_formatDate(transaction.expiresAt!)}',
                    style: TextStyle(
                      fontSize: 11,
                      color: transaction.isExpiringSoon 
                          ? Colors.orange[700] 
                          : Colors.grey[500],
                      fontWeight: transaction.isExpiringSoon 
                          ? FontWeight.bold 
                          : FontWeight.normal,
                    ),
                  ),
                ],
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                transaction.formattedPoints,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              if (transaction.type == PointTransactionType.earn && 
                  transaction.daysUntilExpiration != null)
                Text(
                  '${transaction.daysUntilExpiration}d left',
                  style: TextStyle(
                    fontSize: 10,
                    color: Colors.grey[500],
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _pickDateRange() async {
    final now = DateTime.now();
    final initialRange = _selectedDateRange ??
        DateTimeRange(
          start: now.subtract(const Duration(days: 30)),
          end: now,
        );

    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 2),
      lastDate: DateTime(now.year + 1),
      initialDateRange: initialRange,
      helpText: 'Filter by date range',
    );

    if (range != null) {
      setState(() {
        _selectedDateRange = range;
      });
    }
  }

  void _showAnalytics(
      BuildContext context, List<PointTransaction> transactions) {
    final analytics =
        _buildAnalytics(transactions, Provider.of<PointProvider>(context, listen: false).balance);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 24,
            bottom: MediaQuery.of(context).padding.bottom + 24,
          ),
          child: analytics,
        );
      },
    );
  }

  Widget _buildAnalytics(
      List<PointTransaction> transactions, PointBalance? balance) {
    final now = DateTime.now();
    final months = List<DateTime>.generate(
      6,
      (i) => DateTime(now.year, now.month - i, 1),
    ).reversed.toList();

    final Map<String, _MonthlyStats> stats = {
      for (final month in months)
        DateFormat('MMM').format(month): const _MonthlyStats(),
    };

    for (final transaction in transactions) {
      final key = DateFormat('MMM').format(
          DateTime(transaction.createdAt.year, transaction.createdAt.month));
      if (!stats.containsKey(key)) continue;
      final current = stats[key]!;
      switch (transaction.type) {
        case PointTransactionType.earn:
        case PointTransactionType.referral:
        case PointTransactionType.birthday:
          stats[key] = current.copyWith(
            earned: current.earned + transaction.points,
          );
          break;
        case PointTransactionType.redeem:
        case PointTransactionType.expire:
          stats[key] = current.copyWith(
            redeemed: current.redeemed + transaction.points,
          );
          break;
        default:
          break;
      }
    }

    final maxValue = stats.values
        .map((s) => s.earned > s.redeemed ? s.earned : s.redeemed)
        .fold<int>(0, (prev, elem) => elem > prev ? elem : prev)
        .toDouble()
        .clamp(1, double.infinity);

    final liability = balance?.currentBalance ?? 0;
    final expiringSoon = _expiringSoon.fold<int>(0, (sum, t) => sum + t.points);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Loyalty Analytics',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Earn vs Redeem (last 6 months)',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 160,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: stats.entries.map((entry) {
              final width = 36.0;
              final earnedHeight = (entry.value.earned / maxValue) * 140;
              final redeemedHeight = (entry.value.redeemed / maxValue) * 140;
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 6),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Container(
                      width: width,
                      height: earnedHeight,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Container(
                      width: width,
                      height: redeemedHeight,
                      decoration: BoxDecoration(
                        color: Colors.redAccent.shade200,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      entry.key,
                      style: const TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'Program Health',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _AnalyticsTile(
                title: 'Outstanding liability',
                value: '$liability pts',
                subtitle: 'Redeemable by customers today',
                color: Colors.blueGrey.shade700,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _AnalyticsTile(
                title: 'Expiring soon',
                value: '$expiringSoon pts',
                subtitle: 'Set to expire within 30 days',
                color: Colors.orange.shade700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Cohort snapshot',
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Top earners are progressing ${_selectedFilter == PointTransactionType.redeem ? 'more slowly' : 'steadily'} this month. Consider targeted bonuses to increase redemptions.',
          style: TextStyle(color: Colors.grey[600], fontSize: 12),
        ),
      ],
    );
  }

  Color _getTransactionColor(PointTransactionType type) {
    switch (type) {
      case PointTransactionType.earn:
        return Colors.green;
      case PointTransactionType.redeem:
        return Colors.orange;
      case PointTransactionType.expire:
        return Colors.red;
      case PointTransactionType.adjust:
        return Colors.blue;
      case PointTransactionType.referral:
        return Colors.purple;
      case PointTransactionType.birthday:
        return Colors.pink;
      case PointTransactionType.refund:
        return Colors.cyan;
    }
  }

  IconData _getTransactionIcon(PointTransactionType type) {
    switch (type) {
      case PointTransactionType.earn:
        return Icons.add_circle;
      case PointTransactionType.redeem:
        return Icons.remove_circle;
      case PointTransactionType.expire:
        return Icons.cancel;
      case PointTransactionType.adjust:
        return Icons.edit;
      case PointTransactionType.referral:
        return Icons.people;
      case PointTransactionType.birthday:
        return Icons.cake;
      case PointTransactionType.refund:
        return Icons.refresh;
    }
  }

  String _getDefaultDescription(PointTransactionType type) {
    switch (type) {
      case PointTransactionType.earn:
        return 'Points earned';
      case PointTransactionType.redeem:
        return 'Points redeemed';
      case PointTransactionType.expire:
        return 'Points expired';
      case PointTransactionType.adjust:
        return 'Points adjusted';
      case PointTransactionType.referral:
        return 'Referral bonus';
      case PointTransactionType.birthday:
        return 'Birthday bonus';
      case PointTransactionType.refund:
        return 'Points refunded';
    }
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      if (difference.inHours == 0) {
        if (difference.inMinutes == 0) {
          return 'Just now';
        }
        return '${difference.inMinutes}m ago';
      }
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return DateFormat('MMM d, y').format(date);
    }
  }
}

class _MonthlyStats {
  final int earned;
  final int redeemed;

  const _MonthlyStats({this.earned = 0, this.redeemed = 0});

  _MonthlyStats copyWith({int? earned, int? redeemed}) {
    return _MonthlyStats(
      earned: earned ?? this.earned,
      redeemed: redeemed ?? this.redeemed,
    );
  }
}

class _AnalyticsTile extends StatelessWidget {
  const _AnalyticsTile({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: color.withOpacity(0.9),
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            style: const TextStyle(
              color: Colors.black54,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}

