import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../../core/constants/app_colors.dart';
import '../../providers/tournament_providers.dart';

class QuickAddPlayerBottomSheet extends ConsumerStatefulWidget {
  final String teamId;
  final String teamName;
  final ValueChanged<String> onPlayerAdded;

  const QuickAddPlayerBottomSheet({
    super.key,
    required this.teamId,
    required this.teamName,
    required this.onPlayerAdded,
  });

  @override
  ConsumerState<QuickAddPlayerBottomSheet> createState() => _QuickAddPlayerBottomSheetState();
}

class _QuickAddPlayerBottomSheetState extends ConsumerState<QuickAddPlayerBottomSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _jerseyController = TextEditingController();

  String _selectedRole = 'Batsman';
  String _selectedDesignation = 'Team Member';
  bool _isLoading = false;

  final List<String> _roles = ['Batsman', 'Bowler', 'All-rounder', 'Wicketkeeper'];
  final List<String> _designations = ['Team Member', 'Captain', 'Vice Captain'];

  @override
  void dispose() {
    _nameController.dispose();
    _jerseyController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _isLoading = true);

    try {
      final int? jerseyNum = int.tryParse(_jerseyController.text.trim());
      final repo = ref.read(playerRepositoryProvider);

      final newPlayerId = await repo.addPlayerToSquad(
        teamId: widget.teamId,
        name: _nameController.text.trim(),
        role: _selectedRole,
        designation: _selectedDesignation,
        jerseyNumber: jerseyNum,
      );

      // Refresh providers
      ref.invalidate(playersProvider);
      ref.invalidate(teamPlayersStreamProvider(widget.teamId));

      if (mounted) {
        Navigator.pop(context);
        widget.onPlayerAdded(newPlayerId);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: AppColors.accent, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_nameController.text.trim()} added to ${widget.teamName}!',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.bold, color: Colors.white),
                  ),
                ),
              ],
            ),
            backgroundColor: AppColors.cardBackground,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error adding player: $e', style: GoogleFonts.outfit(color: Colors.white)),
            backgroundColor: AppColors.wicket,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
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
                        child: const Icon(Icons.person_add_alt_1_rounded, color: AppColors.accent, size: 20),
                      ),
                      const SizedBox(width: 10),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add Player to Squad',
                            style: GoogleFonts.outfit(fontSize: 17, fontWeight: FontWeight.w900, color: AppColors.textPrimary),
                          ),
                          Text(
                            widget.teamName,
                            style: GoogleFonts.outfit(fontSize: 12, fontWeight: FontWeight.bold, color: AppColors.accent),
                          ),
                        ],
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: AppColors.textMuted),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Player Name Field
              TextFormField(
                controller: _nameController,
                autofocus: true,
                style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Player Name *',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  hintText: 'e.g. Usama Tariq',
                  hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  prefixIcon: const Icon(Icons.person_outline, color: AppColors.accent),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
                validator: (val) => (val == null || val.trim().isEmpty) ? 'Please enter player name' : null,
              ),
              const SizedBox(height: 14),

              // Role and Designation Dropdowns
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedRole,
                      dropdownColor: AppColors.cardBackground,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Role',
                        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _roles.map((r) => DropdownMenuItem(value: r, child: Text(r))).toList(),
                      onChanged: (val) => setState(() => _selectedRole = val!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedDesignation,
                      dropdownColor: AppColors.cardBackground,
                      style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 13),
                      decoration: InputDecoration(
                        labelText: 'Designation',
                        labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 12),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                      ),
                      items: _designations.map((d) => DropdownMenuItem(value: d, child: Text(d))).toList(),
                      onChanged: (val) => setState(() => _selectedDesignation = val!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // Optional Jersey Number
              TextFormField(
                controller: _jerseyController,
                keyboardType: TextInputType.number,
                style: GoogleFonts.outfit(color: AppColors.textPrimary, fontSize: 14),
                decoration: InputDecoration(
                  labelText: 'Jersey Number (Optional)',
                  labelStyle: GoogleFonts.outfit(color: AppColors.textSecondary, fontSize: 13),
                  hintText: 'e.g. 7',
                  hintStyle: GoogleFonts.outfit(color: AppColors.textMuted, fontSize: 13),
                  filled: true,
                  fillColor: AppColors.surfaceLight,
                  prefixIcon: const Icon(Icons.tag_rounded, color: AppColors.accentCyan),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: const BorderSide(color: AppColors.accentCyan, width: 1.5),
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(color: Colors.black, strokeWidth: 2))
                      : const Icon(Icons.add_task_rounded),
                  label: Text(
                    _isLoading ? 'Adding Player...' : 'ADD TO SQUAD',
                    style: GoogleFonts.outfit(fontWeight: FontWeight.w900, fontSize: 13),
                  ),
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
}
