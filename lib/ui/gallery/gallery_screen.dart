import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../view_models/gallery_view_model.dart';
import '../../models/image_item.dart';
import '../../services/media_service.dart';
import 'image_detail_screen.dart';
import '../search/search_screen.dart';
import '../albums/albums_screen.dart';
import '../settings/settings_screen.dart';

class GalleryScreen extends ConsumerStatefulWidget {
  const GalleryScreen({super.key});

  @override
  ConsumerState<GalleryScreen> createState() => _GalleryScreenState();
}

class _GalleryScreenState extends ConsumerState<GalleryScreen> {
  int _currentIndex = 0;
  bool _isLoadingPermissions = false;

  @override
  void initState() {
    super.initState();
    _requestPermissions();
  }

  Future<void> _requestPermissions() async {
    setState(() => _isLoadingPermissions = true);
    final hasPermission = await MediaService.requestPermissions();
    if (!hasPermission && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Gallery permission is required to use this app'),
        ),
      );
    }
    setState(() => _isLoadingPermissions = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Smart Image Gallery'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              ref.read(galleryProvider.notifier).refresh();
            },
          ),
        ],
      ),
      body: _buildCurrentScreen(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() => _currentIndex = index);
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.grid_view),
            label: 'Gallery',
          ),
          NavigationDestination(
            icon: Icon(Icons.search),
            label: 'Search',
          ),
          NavigationDestination(
            icon: Icon(Icons.album),
            label: 'Albums',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
      ),
    );
  }

  Widget _buildCurrentScreen() {
    if (_isLoadingPermissions) {
      return const Center(child: CircularProgressIndicator());
    }

    switch (_currentIndex) {
      case 0:
        return const GalleryGrid();
      case 1:
        return const SearchScreen();
      case 2:
        return const AlbumsScreen();
      case 3:
        return const SettingsScreen();
      default:
        return const GalleryGrid();
    }
  }
}

class GalleryGrid extends ConsumerWidget {
  const GalleryGrid({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final galleryState = ref.watch(galleryProvider);

    return galleryState.when(
      data: (images) {
        if (images.isEmpty) {
          return const Center(
            child: Text('No images found'),
          );
        }

        return GridView.builder(
          padding: const EdgeInsets.all(8),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemCount: images.length,
          itemBuilder: (context, index) {
            final image = images[index];
            return _ImageGridItem(image: image);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (error, stack) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 48, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => ref.read(galleryProvider.notifier).refresh(),
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageGridItem extends ConsumerWidget {
  final ImageItem image;

  const _ImageGridItem({required this.image});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => ImageDetailScreen(image: image),
          ),
        );
      },
      child: Hero(
        tag: image.id,
        child: Stack(
          fit: StackFit.expand,
          children: [
            FutureBuilder<Uint8List?>(
              future: MediaService.getThumbnail(image.asset),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return Image.memory(
                    snapshot.data!,
                    fit: BoxFit.cover,
                  );
                }
                return const Center(child: CircularProgressIndicator());
              },
            ),
            if (image.isFavorite)
              const Positioned(
                top: 8,
                right: 8,
                child: Icon(
                  Icons.favorite,
                  color: Colors.red,
                  size: 24,
                ),
              ),
            if (image.isCaptionGenerating)
              const Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(),
              ),
            // Caption status indicator
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: _buildCaptionStatus(image),
            ),
          ],
        ),
      ),
    );
  }

  /// Build caption status widget showing generation status or caption preview
  Widget _buildCaptionStatus(ImageItem image) {
    if (image.isCaptionGenerating) {
      return Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: const SizedBox(
          height: 24,
          child: Center(
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ),
        ),
      );
    }

    if (image.caption == null) {
      return Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: const Text(
          'No caption',
          style: TextStyle(
            fontSize: 11,
            color: Colors.grey,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    if (image.caption == 'Unable to generate caption for this image' ||
        image.caption == 'Caption generation not available in this version') {
      return Container(
        color: Colors.black54,
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: Tooltip(
          message: image.caption ?? 'ONNX feature not available',
          child: Text(
            '⚠ ${image.caption!}',
            style: const TextStyle(
              fontSize: 10,
              color: Colors.orange,
              fontStyle: FontStyle.italic,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      );
    }

    return Container(
      color: Colors.black54,
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Text(
        image.caption ?? '',
        style: const TextStyle(
          fontSize: 11,
          color: Colors.white,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}
