import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import '../../../../core/constants/edaic_interview_protocol.dart';

/// Overlay interaktif pemandu 8 pertanyaan PHQ-8 berbahasa Indonesia.
/// Didesain ringkas dan ramping agar area wajah pada pratinjau kamera tetap lega.
class InteractiveInterviewOverlay extends StatefulWidget {
  final List<EdaicQuestion> questions;
  final int currentQuestionIndex;
  final bool isRecording;
  final ValueChanged<int> onQuestionChanged;
  final VoidCallback? onAllQuestionsCompleted;

  const InteractiveInterviewOverlay({
    super.key,
    required this.questions,
    required this.currentQuestionIndex,
    required this.isRecording,
    required this.onQuestionChanged,
    this.onAllQuestionsCompleted,
  });

  @override
  State<InteractiveInterviewOverlay> createState() =>
      _InteractiveInterviewOverlayState();
}

class _InteractiveInterviewOverlayState
    extends State<InteractiveInterviewOverlay>
    with SingleTickerProviderStateMixin {
  static const Color _brandTeal = Color(0xFF0D9488);
  static const Color _brandTealLight = Color(0xFF5EEAD4);
  static const Color _emeraldGreen = Color(0xFF10B981);

  late AnimationController _pulseController;
  bool _isCardExpanded = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    if (widget.isRecording) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(InteractiveInterviewOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isRecording != oldWidget.isRecording) {
      if (widget.isRecording) {
        _pulseController.repeat(reverse: true);
      } else {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  EdaicQuestion get _currentQuestion {
    if (widget.currentQuestionIndex >= 0 &&
        widget.currentQuestionIndex < widget.questions.length) {
      return widget.questions[widget.currentQuestionIndex];
    }
    return widget.questions.first;
  }

  bool get _hasPrevious => widget.currentQuestionIndex > 0;
  bool get _hasNext =>
      widget.currentQuestionIndex < widget.questions.length - 1;

  void _goToPrevious() {
    if (_hasPrevious) {
      HapticFeedback.lightImpact();
      widget.onQuestionChanged(widget.currentQuestionIndex - 1);
    }
  }

  void _goToNext() {
    HapticFeedback.lightImpact();
    if (_hasNext) {
      widget.onQuestionChanged(widget.currentQuestionIndex + 1);
    } else {
      widget.onAllQuestionsCompleted?.call();
    }
  }

  void _showQuestionListModal() {
    HapticFeedback.selectionClick();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF0F172A),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.72,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Row(
                      children: [
                        Icon(
                          Icons.checklist_rounded,
                          color: _brandTealLight,
                          size: 20,
                        ),
                        SizedBox(width: 8),
                        Text(
                          'Daftar Pertanyaan PHQ-8',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded, color: Colors.white70),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                const Text(
                  '8 butir skrining gejala dalam 2 minggu terakhir',
                  style: TextStyle(
                    color: Colors.white60,
                    fontSize: 11.5,
                  ),
                ),
                const SizedBox(height: 12),
                Flexible(
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: widget.questions.length,
                    separatorBuilder: (_, _) => const Divider(
                      color: Colors.white10,
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final q = widget.questions[index];
                      final isSelected = index == widget.currentQuestionIndex;
                      return ListTile(
                        dense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        leading: CircleAvatar(
                          radius: 14,
                          backgroundColor: isSelected
                              ? _brandTeal
                              : Colors.white.withValues(alpha: 0.1),
                          child: Text(
                            '${q.number}',
                            style: TextStyle(
                              color: isSelected ? Colors.white : Colors.white70,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        title: Text(
                          q.questionIndonesian,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isSelected ? Colors.white : Colors.white70,
                            fontSize: 12,
                            fontWeight: isSelected
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        subtitle: Text(
                          q.phq8Badge,
                          style: TextStyle(
                            color: isSelected ? _brandTealLight : Colors.white38,
                            fontSize: 10,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(
                                Icons.check_circle_rounded,
                                color: _emeraldGreen,
                                size: 18,
                              )
                            : null,
                        onTap: () {
                          Navigator.pop(ctx);
                          HapticFeedback.lightImpact();
                          widget.onQuestionChanged(index);
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final question = _currentQuestion;
    final total = widget.questions.length;
    final progress = (widget.currentQuestionIndex + 1) / total;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: widget.isRecording
              ? _emeraldGreen.withValues(alpha: 0.75)
              : _brandTeal.withValues(alpha: 0.55),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.isRecording
                ? _emeraldGreen.withValues(alpha: 0.18)
                : Colors.black.withValues(alpha: 0.35),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // 1. Header Ringkas (Kategori PHQ-8, Posisi, Equalizer, Daftar Soal, Collapse)
          Padding(
            padding: const EdgeInsets.fromLTRB(10, 5, 8, 4),
            child: Row(
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 7,
                      vertical: 2.5,
                    ),
                    decoration: BoxDecoration(
                      color: _brandTeal.withValues(alpha: 0.28),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: _brandTealLight.withValues(alpha: 0.5),
                        width: 0.7,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(question.icon, color: _brandTealLight, size: 12),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            question.category,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: _brandTealLight,
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  '${widget.currentQuestionIndex + 1}/$total',
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const Spacer(),
                if (widget.isRecording) ...[
                  _buildAnimatedEqualizer(),
                  const SizedBox(width: 6),
                ],
                InkWell(
                  onTap: _showQuestionListModal,
                  borderRadius: BorderRadius.circular(6),
                  child: const Padding(
                    padding: EdgeInsets.all(3),
                    child: Icon(
                      Icons.format_list_bulleted_rounded,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      _isCardExpanded = !_isCardExpanded;
                    });
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.all(3),
                    child: Icon(
                      _isCardExpanded
                          ? Icons.keyboard_arrow_up_rounded
                          : Icons.keyboard_arrow_down_rounded,
                      color: Colors.white70,
                      size: 18,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Indikator Progres Pertanyaan
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(2),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 2,
                backgroundColor: Colors.white.withValues(alpha: 0.12),
                valueColor: AlwaysStoppedAnimation<Color>(
                  widget.isRecording ? _emeraldGreen : _brandTeal,
                ),
              ),
            ),
          ),

          // 2. Isi Pertanyaan Bahasa Indonesia (Simpel & Jelas)
          if (_isCardExpanded) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 5),
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: KeyedSubtree(
                  key: ValueKey<String>(question.id),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      question.questionIndonesian,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12.2,
                        fontWeight: FontWeight.w600,
                        height: 1.24,
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // 3. Navigasi Simpel (Sebelumnya / Berikutnya / Selesai)
            Container(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.25),
                borderRadius: const BorderRadius.vertical(
                  bottom: Radius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(6),
                      onTap: _hasPrevious ? _goToPrevious : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.arrow_back_rounded,
                              size: 13,
                              color: _hasPrevious
                                  ? Colors.white70
                                  : Colors.white24,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                'Sebelumnya',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  color: _hasPrevious
                                      ? Colors.white70
                                      : Colors.white24,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  Flexible(
                    child: Material(
                      color: _hasNext ? _brandTeal : _emeraldGreen,
                      borderRadius: BorderRadius.circular(6),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: _goToNext,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3.5,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Flexible(
                                child: Text(
                                  _hasNext ? 'Berikutnya' : 'Selesai',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 10.5,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _hasNext
                                    ? Icons.arrow_forward_rounded
                                    : Icons.check_circle_rounded,
                                size: 13,
                                color: Colors.white,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Visualizer audio sederhana berupa batang bar yang berdenyut saat rekaman aktif
  Widget _buildAnimatedEqualizer() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final val = _pulseController.value;
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildBar(5 + 6 * val),
            const SizedBox(width: 1.5),
            _buildBar(11 - 6 * val),
            const SizedBox(width: 1.5),
            _buildBar(4 + 7 * val),
          ],
        );
      },
    );
  }

  Widget _buildBar(double height) {
    return Container(
      width: 2,
      height: height.clamp(3.0, 11.0),
      decoration: BoxDecoration(
        color: _emeraldGreen,
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}
