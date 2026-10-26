class PlaylistModel {
  final String id;
  final String name;
  final List<String> songPaths;

  const PlaylistModel({
    required this.id,
    required this.name,
    required this.songPaths,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'songPaths': songPaths,
      };

  factory PlaylistModel.fromJson(Map<String, dynamic> json) => PlaylistModel(
        id: json['id'] as String? ?? '',
        name: json['name'] as String? ?? 'Playlist',
        songPaths: (json['songPaths'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      );

  PlaylistModel copyWith({
    String? id,
    String? name,
    List<String>? songPaths,
  }) {
    return PlaylistModel(
      id: id ?? this.id,
      name: name ?? this.name,
      songPaths: songPaths ?? this.songPaths,
    );
  }
}
