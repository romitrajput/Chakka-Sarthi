import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart' show Supabase;
import 'package:video_player/video_player.dart';
import 'package:sanjay_roadlines_fleet/core/constants/app_colors.dart';

/// Plays the Hindi tutorial video inside the app (no browser, no web address shown).
class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key, required this.title, required this.errorText});
  final String title;
  final String errorText;

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  VideoPlayerController? _video;
  bool _failed = false;
  bool _showControls = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _failed = false);
    final url = Supabase.instance.client.storage.from('app-releases').getPublicUrl('tutorial-hi.mp4');
    final controller = VideoPlayerController.networkUrl(Uri.parse(url));
    try {
      await controller.initialize();
      controller.addListener(_onTick);
      if (!mounted) {
        controller.dispose();
        return;
      }
      setState(() => _video = controller);
      controller.play();
    } catch (_) {
      controller.dispose();
      if (mounted) setState(() => _failed = true);
    }
  }

  void _onTick() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _video?.removeListener(_onTick);
    _video?.dispose();
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    super.dispose();
  }

  String _time(Duration d) =>
      '${d.inMinutes.remainder(60).toString().padLeft(1, '0')}:${d.inSeconds.remainder(60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final v = _video;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: AppColors.ink,
        foregroundColor: Colors.white,
        title: Text(widget.title),
      ),
      body: SafeArea(
        child: Center(
          child: _failed
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.wifi_off, color: Colors.white70, size: 48),
                      const SizedBox(height: 16),
                      Text(widget.errorText,
                          textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16)),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        onPressed: _load,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.brandYellow,
                          foregroundColor: AppColors.ink,
                        ),
                        icon: const Icon(Icons.refresh),
                        label: const Text('Retry'),
                      ),
                    ],
                  ),
                )
              : v == null
                  ? const CircularProgressIndicator(color: AppColors.brandYellow)
                  : GestureDetector(
                      onTap: () => setState(() => _showControls = !_showControls),
                      child: AspectRatio(
                        aspectRatio: v.value.aspectRatio,
                        child: Stack(
                          alignment: Alignment.bottomCenter,
                          children: [
                            VideoPlayer(v),
                            if (v.value.isBuffering)
                              const Center(child: CircularProgressIndicator(color: AppColors.brandYellow)),
                            if (_showControls || !v.value.isPlaying) ...[
                              Center(
                                child: IconButton.filled(
                                  iconSize: 48,
                                  style: IconButton.styleFrom(
                                    backgroundColor: Colors.black54,
                                    foregroundColor: Colors.white,
                                  ),
                                  onPressed: () {
                                    if (v.value.isPlaying) {
                                      v.pause();
                                    } else {
                                      if (v.value.position >= v.value.duration) v.seekTo(Duration.zero);
                                      v.play();
                                    }
                                  },
                                  icon: Icon(v.value.isPlaying ? Icons.pause : Icons.play_arrow),
                                ),
                              ),
                              Container(
                                color: Colors.black45,
                                padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                                child: Row(
                                  children: [
                                    Text(_time(v.value.position),
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: VideoProgressIndicator(
                                        v,
                                        allowScrubbing: true,
                                        colors: const VideoProgressColors(
                                          playedColor: AppColors.brandYellow,
                                          bufferedColor: Colors.white38,
                                          backgroundColor: Colors.white12,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Text(_time(v.value.duration),
                                        style: const TextStyle(color: Colors.white, fontSize: 12)),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
        ),
      ),
    );
  }
}
