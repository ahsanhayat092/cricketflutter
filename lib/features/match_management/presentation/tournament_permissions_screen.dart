import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/constants/app_colors.dart';
import '../../scoring/models/tournament_model.dart';
import '../../auth/models/tournament_member_model.dart';
import '../providers/tournament_providers.dart';

class TournamentPermissionsScreen extends ConsumerStatefulWidget {
  const TournamentPermissionsScreen({super.key});

  @override
  ConsumerState<TournamentPermissionsScreen> createState() => _TournamentPermissionsScreenState();
}

class _TournamentPermissionsScreenState extends ConsumerState<TournamentPermissionsScreen> {
  bool _showPin = false;

  void _sharePinWhatsApp(TournamentModel tournament) async {
    final message = '🏏 *Ground Scorer PIN for ${tournament.name}*\n\n'
        'Use 4-digit PIN: *${tournament.scorerPin}*\n\n'
        'Live Scorecard Link: ${tournament.shareUrl}\n'
        'Scorers can enter this PIN on matchday to score without logging in.';
    final text = Uri.encodeComponent(message);
    final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
    try {
      if (await canLaunchUrl(url)) {
        await launchUrl(url, mode: LaunchMode.externalApplication);
      }
    } catch (_) {}
  }

  void _showEditPinDialog(TournamentModel tournament) {
    final pinController = TextEditingController(text: tournament.scorerPin);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Edit Ground Scorer PIN',
          style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
        ),
        content: TextField(
          controller: pinController,
          keyboardType: TextInputType.number,
          maxLength: 4,
          style: GoogleFonts.outfit(
            fontSize: 24,
            letterSpacing: 8,
            fontWeight: FontWeight.bold,
            color: AppColors.accent,
          ),
          textAlign: TextAlign.center,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: AppColors.surfaceLight,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('CANCEL', style: GoogleFonts.outfit(color: AppColors.textMuted)),
          ),
          ElevatedButton(
            onPressed: () async {
              final newPin = pinController.text.trim();
              if (newPin.length == 4) {
                final service = ref.read(scoringServiceProvider);
                await service.updateScorerPin(tournamentId: tournament.id, newPin: newPin);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Ground Scorer PIN updated to $newPin!'),
                    backgroundColor: AppColors.cardBackground,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accent,
              foregroundColor: Colors.black,
            ),
            child: Text('SAVE PIN', style: GoogleFonts.outfit(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showInviteMemberModal(TournamentModel tournament) {
    final emailController = TextEditingController();
    final nameController = TextEditingController();
    String selectedRole = 'SCORER';

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.cardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => Padding(
          padding: EdgeInsets.only(
            left: 24,
            right: 24,
            top: 24,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent, size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Invite Member / Scorer',
                    style: GoogleFonts.outfit(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: nameController,
                style: GoogleFonts.outfit(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Full Name *',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  hintText: 'e.g. Ali Khan',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                style: GoogleFonts.outfit(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Email Address *',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  hintText: 'scorer@example.com',
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: selectedRole,
                dropdownColor: AppColors.surfaceLight,
                style: GoogleFonts.outfit(color: AppColors.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Role',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textMuted),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                ),
                items: const [
                  DropdownMenuItem(value: 'SCORER', child: Text('🏏 Match Scorer (Scoring & Lineup)')),
                  DropdownMenuItem(value: 'ADMIN', child: Text('🛡️ Co-Administrator (Full Access)')),
                ],
                onChanged: (val) {
                  if (val != null) setModalState(() => selectedRole = val);
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final email = emailController.text.trim();
                    final name = nameController.text.trim();
                    if (email.isEmpty || name.isEmpty) return;

                    final cleanEmail = email.toLowerCase();
                    final member = TournamentMemberModel(
                      id: '${tournament.id}_$cleanEmail',
                      tournamentId: tournament.id,
                      userId: '',
                      userEmail: cleanEmail,
                      userName: name,
                      role: selectedRole,
                      createdAt: DateTime.now().toIso8601String(),
                    );

                    final service = ref.read(scoringServiceProvider);
                    await service.saveTournamentMember(member);

                    Navigator.pop(ctx);

                    // Offer WhatsApp invite
                    final inviteMsg = '🏏 Hi $name, you have been invited as a *$selectedRole* for *${tournament.name}* on WASA Cricket!\n\n'
                        'Open live tournament portal: ${tournament.shareUrl}\n'
                        'Matchday Ground Scorer PIN: *${tournament.scorerPin}*';
                    final text = Uri.encodeComponent(inviteMsg);
                    final url = Uri.parse('https://api.whatsapp.com/send?text=$text');
                    try {
                      if (await canLaunchUrl(url)) {
                        await launchUrl(url, mode: LaunchMode.externalApplication);
                      }
                    } catch (_) {}
                  },
                  icon: const Icon(Icons.send_rounded, size: 18),
                  label: Text('SAVE & SEND WHATSAPP INVITE', style: GoogleFonts.outfit(fontWeight: FontWeight.w900)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeTournamentAsync = ref.watch(activeTournamentProvider);
    final membersAsync = ref.watch(activeTournamentMembersProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.cardBackground,
        elevation: 0,
        title: Text(
          'People & Permissions',
          style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 18),
        ),
        actions: [
          IconButton(
            onPressed: () {
              final tournament = activeTournamentAsync.value;
              if (tournament != null) _showInviteMemberModal(tournament);
            },
            icon: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent),
          ),
        ],
      ),
      body: activeTournamentAsync.when(
        data: (tournament) {
          if (tournament == null) {
            return const Center(child: Text('No active tournament selected'));
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Tournament Header Banner
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.surfaceLight),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.emoji_events_rounded, color: AppColors.accent, size: 24),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              tournament.name,
                              style: GoogleFonts.outfit(
                                fontSize: 16,
                                fontWeight: FontWeight.w900,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Slug: /t/${tournament.slug} • Format: ${tournament.formatType}',
                        style: GoogleFonts.outfit(fontSize: 12, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Ground Scorer 4-Digit PIN Card
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.accent.withValues(alpha: 0.3)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.pin_rounded, color: AppColors.accent, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Ground Scorer Matchday PIN',
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                              color: AppColors.accent,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            onPressed: () => setState(() => _showPin = !_showPin),
                            icon: Icon(
                              _showPin ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                              size: 18,
                              color: AppColors.accent,
                            ),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Text(
                            _showPin ? tournament.scorerPin : '••••',
                            style: GoogleFonts.outfit(
                              fontSize: 26,
                              fontWeight: FontWeight.w900,
                              letterSpacing: _showPin ? 6 : 4,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const Spacer(),
                          OutlinedButton.icon(
                            onPressed: () => _showEditPinDialog(tournament),
                            icon: const Icon(Icons.edit_rounded, size: 14),
                            label: Text('Edit PIN', style: GoogleFonts.outfit(fontSize: 11)),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: AppColors.accent,
                              side: const BorderSide(color: AppColors.accent),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            onPressed: () => _sharePinWhatsApp(tournament),
                            icon: const Icon(Icons.share_rounded, size: 14),
                            label: Text('WhatsApp', style: GoogleFonts.outfit(fontSize: 11, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: Colors.black,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Ground scorers can enter this 4-digit PIN on any phone to unlock scoring without creating an account.',
                        style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Members List Header
                Row(
                  children: [
                    Text(
                      'Assigned Members & Scorers',
                      style: GoogleFonts.outfit(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _showInviteMemberModal(tournament),
                      icon: const Icon(Icons.add_rounded, size: 16, color: AppColors.accentCyan),
                      label: Text('+ Add Scorer', style: GoogleFonts.outfit(fontSize: 12, color: AppColors.accentCyan)),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Members List
                membersAsync.when(
                  data: (members) {
                    if (members.isEmpty) {
                      return Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppColors.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Center(
                          child: Text(
                            'No dedicated members added yet.\nGround Scorers can use the 4-digit PIN above.',
                            textAlign: TextAlign.center,
                            style: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 12),
                          ),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: members.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final member = members[index];
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: AppColors.cardBackground,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: AppColors.surfaceLight,
                                child: Text(
                                  member.userName.isNotEmpty ? member.userName[0].toUpperCase() : '?',
                                  style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: AppColors.accent),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      member.userName,
                                      style: GoogleFonts.outfit(
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.textPrimary,
                                      ),
                                    ),
                                    Text(
                                      member.userEmail,
                                      style: GoogleFonts.outfit(fontSize: 11, color: AppColors.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: member.isAdmin
                                      ? AppColors.accent.withValues(alpha: 0.15)
                                      : AppColors.surfaceLight,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  member.roleEnum.displayName,
                                  style: GoogleFonts.outfit(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: member.isAdmin ? AppColors.accent : AppColors.textPrimary,
                                  ),
                                ),
                              ),
                              IconButton(
                                onPressed: () async {
                                  final service = ref.read(scoringServiceProvider);
                                  await service.removeTournamentMember(member.id);
                                },
                                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.wicket),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                  loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
                  error: (e, _) => Center(child: Text('Error: $e')),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator(color: AppColors.accent)),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
