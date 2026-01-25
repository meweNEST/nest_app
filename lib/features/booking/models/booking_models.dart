// NEUE DATEI: lib/features/booking/models/booking_models.dart

import 'package:flutter/material.dart';

// Dies ist jetzt der ZENTRALE Ort für diese Typen.

class UserBooking {
  final DateTime day;
  final String timeSlot;
  UserBooking(this.day, this.timeSlot);
}

enum UserMembership {
  regular,
  premium,
}

// Auch die anderen Enums aus den Bottom Sheets gehören hierher
enum MeetingBookingType {
  private,
  shared,
}

enum OccupancyStatus {
  low,
  medium,
  high,
  full,
  notAvailable,
}
