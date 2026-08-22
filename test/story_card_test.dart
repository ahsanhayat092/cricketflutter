import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/features/scoring/models/match_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/innings_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/player_model.dart';
import 'package:wpl_cricket_app/features/scoring/models/batting_score.dart';
import 'package:wpl_cricket_app/features/scoring/models/bowling_score.dart';
import 'package:wpl_cricket_app/features/sharing/presentation/widgets/match_story_card.dart';

void main() {
  group('StoryCard Tests', () {
    const match = MatchModel(
      id: 'match_1',
      matchNumber: 1,
      stage: 'LEAGUE',
      teamAId: 'team_a',
      teamBId: 'team_b',
      date: '2026-08-22',
      status: 'COMPLETED',
      winningTeamId: 'team_a',
      resultText: 'Royal Strikers won by 14 runs',
    );

    const teamA = TeamModel(id: 'team_a', name: 'Royal Strikers', shortName: 'RS');
    const teamB = TeamModel(id: 'team_b', name: 'Titan Warriors', shortName: 'TW');

    const innings1 = InningsModel(
      id: 'inn_1',
      matchId: 'match_1',
      inningsNumber: 1,
      battingTeamId: 'team_a',
      bowlingTeamId: 'team_b',
      runs: 68,
      wickets: 2,
      balls: 24,
    );

    const innings2 = InningsModel(
      id: 'inn_2',
      matchId: 'match_1',
      inningsNumber: 2,
      battingTeamId: 'team_b',
      bowlingTeamId: 'team_a',
      runs: 54,
      wickets: 5,
      balls: 22,
    );

    const player1 = PlayerModel(id: 'p1', teamId: 'team_a', name: 'Babar Azam', role: 'BATSMAN');
    const player2 = PlayerModel(id: 'p2', teamId: 'team_a', name: 'Shaheen Afridi', role: 'BOWLER');

    test('MatchStoryCard initializes all 5 templates without throwing', () {
      for (final template in StoryCardTemplate.values) {
        final widget = MatchStoryCard(
          template: template,
          match: match,
          teamA: teamA,
          teamB: teamB,
          inningsList: const [innings1, innings2],
          allPlayers: const [player1, player2],
          allBattingScores: const [
            BattingScore(id: 'b1', inningsId: 'inn_1', playerId: 'p1', runs: 42, balls: 14, fours: 3, sixes: 4),
          ],
          allBowlingScores: const [
            BowlingScore(id: 'bo1', inningsId: 'inn_2', playerId: 'p2', balls: 6, runs: 8, wickets: 3),
          ],
          potmPlayer: player1,
          highlightBatsman: player1,
          highlightBowler: player2,
        );

        expect(widget.template, equals(template));
        expect(widget.match.id, equals('match_1'));
      }
    });

    test('StoryCardTemplate enum contains 5 defined Instagram Story templates', () {
      expect(StoryCardTemplate.values.length, equals(5));
      expect(StoryCardTemplate.values, contains(StoryCardTemplate.matchResult));
      expect(StoryCardTemplate.values, contains(StoryCardTemplate.playerOfTheMatch));
      expect(StoryCardTemplate.values, contains(StoryCardTemplate.massiveSix));
      expect(StoryCardTemplate.values, contains(StoryCardTemplate.wicketFall));
      expect(StoryCardTemplate.values, contains(StoryCardTemplate.matchOverview));
    });
  });
}
