import 'package:flutter_test/flutter_test.dart';
import 'package:wpl_cricket_app/core/utils/image_url_helper.dart';
import 'package:wpl_cricket_app/features/scoring/models/team_model.dart';

void main() {
  group('ImageUrlHelper Tests', () {
    test('Converts Google Drive view link with sharing parameter to direct lh3 CDN link', () {
      const input = 'https://drive.google.com/file/d/1A2B3C4D5E6F7G8H9I0J/view?usp=sharing';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals('https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J'));
    });

    test('Converts Google Drive view link without params to direct lh3 CDN link', () {
      const input = 'https://drive.google.com/file/d/1A2B3C4D5E6F7G8H9I0J/view';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals('https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J'));
    });

    test('Converts Google Drive open id link to direct lh3 CDN link', () {
      const input = 'https://drive.google.com/open?id=1A2B3C4D5E6F7G8H9I0J';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals('https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J'));
    });

    test('Converts Google Drive uc export link to direct lh3 CDN link', () {
      const input = 'https://drive.google.com/uc?export=view&id=1A2B3C4D5E6F7G8H9I0J';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals('https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J'));
    });

    test('Preserves already converted lh3 links', () {
      const input = 'https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals('https://lh3.googleusercontent.com/d/1A2B3C4D5E6F7G8H9I0J'));
    });

    test('Preserves standard non-Drive web URLs', () {
      const input = 'https://firebasestorage.googleapis.com/v0/b/wpl/o/team_logo.png?alt=media';
      final output = ImageUrlHelper.formatDirectImageUrl(input);
      expect(output, equals(input));
    });

    test('Handles empty and null inputs safely', () {
      expect(ImageUrlHelper.formatDirectImageUrl(''), equals(''));
      expect(ImageUrlHelper.formatDirectImageUrl(null), equals(''));
      expect(ImageUrlHelper.formatDirectImageUrl('   '), equals(''));
    });

    test('TeamModel automatically formats Google Drive logo URL from Firebase map', () {
      final team = TeamModel.fromMap('team-1', {
        'name': 'Royal Strikers',
        'shortName': 'RS',
        'logoUrl': 'https://drive.google.com/file/d/1XYZ_98765-ABC/view?usp=sharing',
      });

      expect(team.formattedLogoUrl, equals('https://lh3.googleusercontent.com/d/1XYZ_98765-ABC'));
      expect(team.logoUrl, equals('https://lh3.googleusercontent.com/d/1XYZ_98765-ABC'));
    });
  });
}
