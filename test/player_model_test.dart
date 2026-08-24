import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/player_model.dart';

void main() {
  group('PlayerModel & Squad Addition Tests', () {
    test('PlayerModel serializes and deserializes properly with isPlayingVI', () {
      final player = PlayerModel(
        id: 'p101',
        teamId: 'team-a',
        name: 'Usama Tariq',
        role: 'All-rounder',
        designation: 'Captain',
        isCaptain: true,
        isViceCaptain: false,
        isPlayingVI: true,
        jerseyNumber: 7,
      );

      final map = player.toMap();
      expect(map['teamId'], 'team-a');
      expect(map['name'], 'Usama Tariq');
      expect(map['role'], 'All-rounder');
      expect(map['designation'], 'Captain');
      expect(map['isCaptain'], isTrue);
      expect(map['isPlayingVI'], isTrue);
      expect(map['jerseyNumber'], 7);

      final reconstructed = PlayerModel.fromMap('p101', map);
      expect(reconstructed.id, 'p101');
      expect(reconstructed.name, 'Usama Tariq');
      expect(reconstructed.role, 'All-rounder');
      expect(reconstructed.isCaptain, isTrue);
      expect(reconstructed.isPlayingVI, isTrue);
      expect(reconstructed.jerseyNumber, 7);
    });

    test('PlayerModel correctly defaults isPlayingVI to true for backwards compatibility', () {
      final json = {
        'teamId': 'team-b',
        'name': 'Ali Khan',
        'role': 'Bowler',
      };

      final player = PlayerModel.fromMap('p102', json);
      expect(player.isPlayingVI, isTrue);
      expect(player.isCaptain, isFalse);
    });

    test('Filtering Playing VI vs all squad players works correctly', () {
      final allPlayers = [
        const PlayerModel(id: 'p1', teamId: 'team-a', name: 'Starter 1'),
        const PlayerModel(id: 'p2', teamId: 'team-a', name: 'Starter 2'),
        const PlayerModel(id: 'p3', teamId: 'team-a', name: 'Starter 3'),
        const PlayerModel(id: 'p4', teamId: 'team-a', name: 'Starter 4'),
        const PlayerModel(id: 'p5', teamId: 'team-a', name: 'Starter 5'),
        const PlayerModel(id: 'p6', teamId: 'team-a', name: 'Starter 6'),
        const PlayerModel(id: 'p7', teamId: 'team-a', name: 'Reserve 1', isPlayingVI: false),
        const PlayerModel(id: 'p8', teamId: 'team-b', name: 'Opponent 1'),
      ];

      final teamAPlayers = allPlayers.where((p) => p.teamId == 'team-a').toList();
      expect(teamAPlayers.length, 7);

      final playingVI = teamAPlayers.where((p) => p.isPlayingVI).toList();
      expect(playingVI.length, 6);

      final reserves = teamAPlayers.where((p) => !p.isPlayingVI).toList();
      expect(reserves.length, 1);
      expect(reserves.first.id, 'p7');
    });
  });
}
