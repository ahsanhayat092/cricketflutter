import 'package:cloud_firestore/cloud_firestore.dart';

/// Safely parse Firestore fields that might be a String, Timestamp, DateTime, or num into an ISO-8601 / formatted String.
String? parseFirestoreDateTimeString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Timestamp) return value.toDate().toIso8601String();
  if (value is DateTime) return value.toIso8601String();
  return value.toString();
}

/// Safely parse any dynamic Firestore field to String
String? parseFirestoreString(dynamic value) {
  if (value == null) return null;
  if (value is String) return value;
  if (value is Timestamp) return value.toDate().toIso8601String();
  return value.toString();
}
