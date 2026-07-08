import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

// Base shimmer box
class _ShimBox extends StatelessWidget {
  final double width, height;
  final double radius;
  const _ShimBox({required this.width, required this.height, this.radius = 6});

  @override
  Widget build(BuildContext context) => Container(
        width: width,
        height: height,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(radius),
        ),
      );
}

Widget _wrap(Widget child) => Shimmer.fromColors(
      baseColor: const Color(0xFFE2E8F0),
      highlightColor: const Color(0xFFF8FAFC),
      child: child,
    );

// ─── Booking card shimmer ──────────────────────────────────────────────────────

class ShimmerBookingCard extends StatelessWidget {
  const ShimmerBookingCard({super.key});

  @override
  Widget build(BuildContext context) => _wrap(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                const _ShimBox(width: 100, height: 11),
                const Spacer(),
                const _ShimBox(width: 72, height: 24, radius: 8),
              ]),
              const SizedBox(height: 10),
              const _ShimBox(width: 160, height: 14),
              const SizedBox(height: 8),
              const _ShimBox(width: 130, height: 11),
              const SizedBox(height: 8),
              Row(children: const [
                _ShimBox(width: 80, height: 12),
                SizedBox(width: 16),
                _ShimBox(width: 80, height: 12),
                SizedBox(width: 16),
                _ShimBox(width: 80, height: 12),
              ]),
              const SizedBox(height: 8),
              const _ShimBox(width: 140, height: 11),
            ],
          ),
        ),
      );
}

// ─── Operation card shimmer ────────────────────────────────────────────────────

class ShimmerOperationCard extends StatelessWidget {
  const ShimmerOperationCard({super.key});

  @override
  Widget build(BuildContext context) => _wrap(
        Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimBox(width: 140, height: 14),
                    SizedBox(height: 6),
                    _ShimBox(width: 120, height: 11),
                    SizedBox(height: 6),
                    _ShimBox(width: 180, height: 11),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: const [
                  _ShimBox(width: 60, height: 14),
                  SizedBox(height: 4),
                  _ShimBox(width: 50, height: 10),
                ],
              ),
            ],
          ),
        ),
      );
}

// ─── Customer card shimmer ─────────────────────────────────────────────────────

class ShimmerCustomerCard extends StatelessWidget {
  const ShimmerCustomerCard({super.key});

  @override
  Widget build(BuildContext context) => _wrap(
        Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const _ShimBox(width: 44, height: 44, radius: 12),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: const [
                    _ShimBox(width: 130, height: 14),
                    SizedBox(height: 6),
                    _ShimBox(width: 100, height: 11),
                  ],
                ),
              ),
              const _ShimBox(width: 56, height: 22, radius: 6),
            ],
          ),
        ),
      );
}

// ─── Customer detail shimmer ───────────────────────────────────────────────────

class ShimmerCustomerDetail extends StatelessWidget {
  const ShimmerCustomerDetail({super.key});

  @override
  Widget build(BuildContext context) => _wrap(
        SingleChildScrollView(
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
          child: Column(
            children: [
              // Header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 32),
                color: Colors.white,
                child: Column(
                  children: const [
                    _ShimBox(width: 64, height: 64, radius: 18),
                    SizedBox(height: 10),
                    _ShimBox(width: 140, height: 16),
                    SizedBox(height: 6),
                    _ShimBox(width: 100, height: 12),
                    SizedBox(height: 8),
                    _ShimBox(width: 60, height: 22, radius: 20),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Stats
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: List.generate(4, (_) => const Column(
                    children: [
                      _ShimBox(width: 36, height: 36, radius: 9),
                      SizedBox(height: 6),
                      _ShimBox(width: 50, height: 12),
                      SizedBox(height: 4),
                      _ShimBox(width: 40, height: 10),
                    ],
                  )),
                ),
              ),
              const SizedBox(height: 12),
              // Info card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  children: List.generate(3, (i) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(children: [
                      const _ShimBox(width: 14, height: 14, radius: 4),
                      const SizedBox(width: 10),
                      const _ShimBox(width: 80, height: 12),
                      const SizedBox(width: 16),
                      _ShimBox(width: i == 0 ? 120 : 90, height: 12),
                    ]),
                  )),
                ),
              ),
              const SizedBox(height: 12),
              // Booking history
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const _ShimBox(width: 120, height: 12),
                    const SizedBox(height: 12),
                    ...List.generate(3, (_) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Row(children: [
                            _ShimBox(width: 110, height: 13),
                            Spacer(),
                            _ShimBox(width: 70, height: 22, radius: 6),
                          ]),
                          SizedBox(height: 6),
                          _ShimBox(width: 150, height: 11),
                          SizedBox(height: 8),
                          Row(children: [
                            _ShimBox(width: 80, height: 13),
                            Spacer(),
                            _ShimBox(width: 70, height: 22, radius: 6),
                          ]),
                        ],
                      ),
                    )),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
}

// ─── Generic list shimmer ──────────────────────────────────────────────────────

class ShimmerList extends StatelessWidget {
  final Widget Function() cardBuilder;
  final int count;
  const ShimmerList({super.key, required this.cardBuilder, this.count = 6});

  @override
  Widget build(BuildContext context) => ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: count,
        itemBuilder: (_, __) => cardBuilder(),
      );
}
