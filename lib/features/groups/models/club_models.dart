class Club {
  const Club({
    required this.id,
    required this.ownerId,
    required this.name,
    required this.description,
    required this.sport,
    required this.city,
    required this.isPublic,
    required this.memberCount,
    required this.isMember,
    required this.isOwner,
    this.coverUrl,
    this.ownerName,
  });

  final String id;
  final String ownerId;
  final String name;
  final String description;
  final String sport;
  final String city;
  final bool isPublic;
  final int memberCount;
  final bool isMember;
  final bool isOwner;
  final String? coverUrl;
  final String? ownerName;
}

class ClubEvent {
  const ClubEvent({
    required this.id,
    required this.clubId,
    required this.clubName,
    required this.createdBy,
    required this.title,
    required this.description,
    required this.sport,
    required this.locationName,
    required this.startsAt,
    required this.participantCount,
    required this.isJoined,
  });

  final String id;
  final String clubId;
  final String clubName;
  final String createdBy;
  final String title;
  final String description;
  final String sport;
  final String locationName;
  final DateTime startsAt;
  final int participantCount;
  final bool isJoined;
}
