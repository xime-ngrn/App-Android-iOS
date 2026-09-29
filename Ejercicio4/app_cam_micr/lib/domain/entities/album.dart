class Album {
  const Album({
    required this.id,
    required this.name,
    required this.createdAt,
    this.itemCount = 0,
  });

  final int id;
  final String name;
  final DateTime createdAt;
  final int itemCount;
}
