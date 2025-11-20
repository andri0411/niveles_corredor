class SceneConfig {
  final String groundImage;
  final String? spikeImage;
  final String? doorImage;

  SceneConfig({required this.groundImage, this.spikeImage, this.doorImage});
}

/// Loads scene configuration. Currently a stub that returns hard-coded
/// asset names. Replace implementation to fetch from DB or remote service.
Future<SceneConfig> loadSceneConfig() async {
  // TODO: implement actual DB/network fetch here
  return SceneConfig(
    groundImage: 'map.png',
    spikeImage: 'pinchos.png',
    doorImage: 'puerta.png',
  );
}
