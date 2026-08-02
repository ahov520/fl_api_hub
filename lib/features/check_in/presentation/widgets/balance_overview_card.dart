/// Dashboard card showing the aggregated balance trend across all accounts.
///
/// Displays the current total balance, today's estimated consumption, and a
/// 7-day line chart built from locally persisted [BalanceSnapshot]s.
library;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme/design_tokens.dart';
import '../../../../core/widgets/app_card.dart';
import '../../../../core/widgets/stat_tile.dart';
import '../../../accounts/presentation/providers/balance_snapshot_providers.dart';

/// Aggregated balance overview for the check-in dashboard.
class BalanceOverviewCard extends ConsumerWidget {
  const BalanceOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final totalBalance = ref.watch(totalBalanceProvider);
    final todayConsumption = ref.watch(todayConsumptionProvider);
    final trend = ref.watch(sevenDayBalanceTotalsProvider);

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.account_balance_wallet_outlined,
                color: Theme.of(context).colorScheme.primary,
                size: 20,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                '余额总览',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: StatTile(
                  label: '总余额',
                  value: totalBalance != null
                      ? '\$${totalBalance.toStringAsFixed(2)}'
                      : '--',
                  icon: Icons.payments_outlined,
                ),
              ),
              Expanded(
                child: StatTile(
                  label: '今日消耗',
                  value: todayConsumption != null
                      ? '\$${todayConsumption.toStringAsFixed(2)}'
                      : '--',
                  icon: Icons.trending_down,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          _BalanceTrendChart(trend: trend),
        ],
      ),
    );
  }
}

class _BalanceTrendChart extends StatelessWidget {
  const _BalanceTrendChart({required this.trend});

  final Map<DateTime, double> trend;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    if (trend.isEmpty) {
      return SizedBox(
        height: 120,
        child: Center(
          child: Text(
            '暂无趋势数据\n刷新账号后自动记录余额快照',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      );
    }

    // Sort by day and take the last 7 entries.
    final entries = trend.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    final recent = entries.length > 7
        ? entries.sublist(entries.length - 7)
        : entries;

    final spots = <FlSpot>[];
    for (var i = 0; i < recent.length; i++) {
      spots.add(FlSpot(i.toDouble(), recent[i].value));
    }

    final minY = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    final maxY = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    final padding = (maxY - minY) * 0.1;
    final intervalX = recent.length > 1 ? (recent.length - 1) / 3 : 1.0;

    return SizedBox(
      height: 140,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            drawVerticalLine: false,
            horizontalInterval: (maxY - minY) > 0 ? (maxY - minY) / 3 : 1,
            getDrawingHorizontalLine: (_) => FlLine(
              color: colorScheme.outlineVariant.withValues(alpha: 0.3),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            rightTitles: const AxisTitles(),
            topTitles: const AxisTitles(),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                interval: intervalX,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= recent.length) {
                    return const SizedBox.shrink();
                  }
                  final date = recent[index].key;
                  return Padding(
                    padding: const EdgeInsets.only(top: AppSpacing.xs),
                    child: Text(
                      '${date.month}/${date.day}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                },
              ),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) {
                  return Text(
                    '\$${value.toStringAsFixed(1)}',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  );
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          minY: minY - padding,
          maxY: maxY + padding,
          lineBarsData: [
            LineChartBarData(
              spots: spots,
              isCurved: true,
              curveSmoothness: 0.3,
              color: colorScheme.primary,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, bar, index) {
                  return FlDotCirclePainter(
                    radius: 3,
                    color: colorScheme.primary,
                    strokeWidth: 2,
                    strokeColor: colorScheme.surface,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    colorScheme.primary.withValues(alpha: 0.25),
                    colorScheme.primary.withValues(alpha: 0.02),
                  ],
                ),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipColor: (_) => colorScheme.inverseSurface,
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final date = recent[spot.x.toInt()].key;
                  return LineTooltipItem(
                    '${date.month}/${date.day}\n\$${spot.y.toStringAsFixed(2)}',
                    TextStyle(
                      color: colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
        duration: AppDuration.normal,
        curve: AppMotion.standard,
      ),
    );
  }
}
