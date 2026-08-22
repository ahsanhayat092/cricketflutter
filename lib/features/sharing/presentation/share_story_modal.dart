import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/constants/app_colors.dart';
import '../../scoring/models/match_model.dart';
import '../../scoring/models/team_model.dart';
import '../../scoring/models/player_model.dart';
import '../../scoring/models/innings_model.dart';
import '../../scoring/models/batting_score.dart';
import '../../scoring/models/bowling_score.dart';
import '../services/story_card_generator.dart';
import 'widgets/match_story_card.dart';

class ShareStoryModal extends StatefulWidget {
  final MatchModel match;
  final TeamModel teamA;
  final TeamModel teamB;
  final List<InningsModel> inningsList;
  final List<PlayerModel> allPlayers;
  final List<BattingScore> allBattingScores;
  final List<BowlingScore> allBowlingScores;
  final StoryCardTemplate initialTemplate;
  final PlayerModel? initialPotm;
  final PlayerModel? initialBatsman;
  final PlayerModel? initialBowler;

  const ShareStoryModal({
    super.key,
    required this.match,
    required this.teamA,
    required this.teamB,
    required this.inningsList,
    required this.allPlayers,
    this.allBattingScores = const [],
    this.allBowlingScores = const [],
    this.initialTemplate = StoryCardTemplate.matchResult,
    this.initialPotm,
    this.initialBatsman,
    this.initialBowler,
  });

  static Future<void> show(
    BuildContext context, {
    required MatchModel match,
    required TeamModel teamA,
    required TeamModel teamB,
    required List<InningsModel> inningsList,
    required List<PlayerModel> allPlayers,
    List<BattingScore> allBattingScores = const [],
    List<BowlingScore> allBowlingScores = const [],
    StoryCardTemplate initialTemplate = StoryCardTemplate.matchResult,
    PlayerModel? initialPotm,
    PlayerModel? initialBatsman,
    PlayerModel? initialBowler,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ShareStoryModal(
        match: match,
        teamA: teamA,
        teamB: teamB,
        inningsList: inningsList,
        allPlayers: allPlayers,
        allBattingScores: allBattingScores,
        allBowlingScores: allBowlingScores,
        initialTemplate: initialTemplate,
        initialPotm: initialPotm,
        initialBatsman: initialBatsman,
        initialBowler: initialBowler,
      ),
    );
  }

  @override
  State<ShareStoryModal> createState() => _ShareStoryModalState();
}

class _ShareStoryModalState extends State<ShareStoryModal> {
  final GlobalKey _storyKey = GlobalKey();
  late StoryCardTemplate _selectedTemplate;
  PlayerModel? _selectedPotm;
  bool _isSharing = false;

  @override
  void initState() {
    super.initState();
    _selectedTemplate = widget.initialTemplate;
    _selectedPotm = widget.initialPotm;
  }

  Future<void> _shareStory() async {
    if (_isSharing) return;
    setState(() => _isSharing = true);

    try {
      final templateName = _selectedTemplate.name;
      final filename = 'wpl_match_${widget.match.id}_$templateName.png';
      final caption = _buildShareCaption();

      final success = await StoryCardGenerator.captureAndShare(
        key: _storyKey,
        filename: filename,
        shareText: caption,
        subject: 'WASA Premier League 2026',
        pixelRatio: 3.0,
      );

      if (mounted && success) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Story card shared successfully! 🏏'),
            backgroundColor: AppColors.accent,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to share story: $e'),
            backgroundColor: AppColors.wicket,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  String _buildShareCaption() {
    final tA = widget.teamA.shortName;
    final tB = widget.teamB.shortName;
    final verdict = widget.match.resultText ?? 'Live on WASA Premier League';

    switch (_selectedTemplate) {
      case StoryCardTemplate.matchResult:
        return '🏆 $verdict!\n$tA vs $tB • WASA Premier League 2026 #WPL2026 #CricketStory';
      case StoryCardTemplate.playerOfTheMatch:
        final name = _selectedPotm?.name ?? 'Hero of the match';
        return '🌟 Player of the Match: $name!\n$tA vs $tB • WASA Premier League #POTM #WPL2026';
      case StoryCardTemplate.massiveSix:
        return '🚀 MAXIMUM! Huge 6 in $tA vs $tB match! #WPL2026 #BigSix #CricketMoments';
      case StoryCardTemplate.wicketFall:
        return '⚡ TIMBER! Crucial wicket falls in $tA vs $tB! #WPL2026 #WicketMoment';
      case StoryCardTemplate.matchOverview:
        return '📊 Match Summary • $tA vs $tB • WASA Premier League 2026 #WPL2026';
    }
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final maxHeight = mediaQuery.size.height * 0.92;

    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight),
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag Handle
          Container(
            margin: const EdgeInsets.only(top: 10, bottom: 6),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: Colors.white24,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: AppColors.accent.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.auto_awesome_rounded, color: AppColors.accent, size: 20),
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'SHARE STORY CARDS',
                          style: GoogleFonts.outfit(
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                            color: AppColors.textPrimary,
                            letterSpacing: 0.5,
                          ),
                        ),
                        Text(
                          'Instagram Story / WhatsApp Status (9:16)',
                          style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Colors.white12),

          // Template Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                _buildTemplatePill(
                  template: StoryCardTemplate.matchResult,
                  label: '🏆 Result',
                ),
                const SizedBox(width: 8),
                _buildTemplatePill(
                  template: StoryCardTemplate.playerOfTheMatch,
                  label: '🌟 POTM Award',
                ),
                const SizedBox(width: 8),
                _buildTemplatePill(
                  template: StoryCardTemplate.massiveSix,
                  label: '💥 Big 6',
                ),
                const SizedBox(width: 8),
                _buildTemplatePill(
                  template: StoryCardTemplate.wicketFall,
                  label: '🎯 Wicket',
                ),
                const SizedBox(width: 8),
                _buildTemplatePill(
                  template: StoryCardTemplate.matchOverview,
                  label: '📊 Overview',
                ),
              ],
            ),
          ),

          // Story Card Canvas Preview Area
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Center(
                child: RepaintBoundary(
                  key: _storyKey,
                  child: MatchStoryCard(
                    template: _selectedTemplate,
                    match: widget.match,
                    teamA: widget.teamA,
                    teamB: widget.teamB,
                    inningsList: widget.inningsList,
                    allPlayers: widget.allPlayers,
                    allBattingScores: widget.allBattingScores,
                    allBowlingScores: widget.allBowlingScores,
                    potmPlayer: _selectedPotm,
                    highlightBatsman: widget.initialBatsman,
                    highlightBowler: widget.initialBowler,
                  ),
                ),
              ),
            ),
          ),

          // Bottom Action Bar
          Container(
            padding: EdgeInsets.fromLTRB(20, 12, 20, mediaQuery.padding.bottom + 12),
            decoration: BoxDecoration(
              color: AppColors.surface,
              border: Border(top: BorderSide(color: Colors.white.withValues(alpha: 0.08))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.accent,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 2,
                    ),
                    icon: _isSharing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                          )
                        : const Icon(Icons.share_rounded, size: 20),
                    label: Text(
                      _isSharing ? 'GENERATING STORY...' : 'SHARE INSTAGRAM STORY',
                      style: GoogleFonts.outfit(
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 0.5,
                      ),
                    ),
                    onPressed: _isSharing ? null : _shareStory,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTemplatePill({
    required StoryCardTemplate template,
    required String label,
  }) {
    final isSelected = _selectedTemplate == template;

    return InkWell(
      onTap: () => setState(() => _selectedTemplate = template),
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.accent : AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.accent : Colors.white12,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.w900 : FontWeight.w600,
            color: isSelected ? Colors.black : AppColors.textSecondary,
          ),
        ),
      ),
    );
  }
}
