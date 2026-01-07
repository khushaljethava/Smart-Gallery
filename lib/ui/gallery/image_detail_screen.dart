import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/image_item.dart';
import '../../services/media_service.dart';
import '../../view_models/gallery_view_model.dart';

class ImageDetailScreen extends ConsumerStatefulWidget {
  final ImageItem image;

  const ImageDetailScreen({super.key, required this.image});

  @override
  ConsumerState<ImageDetailScreen> createState() => _ImageDetailScreenState();
}

class _ImageDetailScreenState extends ConsumerState<ImageDetailScreen> {
  Uint8List? _fullImage;
  bool _isLoadingImage = true;

  @override
  void initState() {
    super.initState();
    _loadFullImage();
  }

  Future<void> _loadFullImage() async {
    // Yield control before heavy I/O operation
    await Future.delayed(Duration.zero);
    final imageBytes = await MediaService.getFullImage(widget.image.asset);
    if (mounted) {
      setState(() {
        _fullImage = imageBytes;
        _isLoadingImage = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentImage = ref.watch(galleryProvider).value?.firstWhere(
      (img) => img.id == widget.image.id,
      orElse: () => widget.image,
    ) ?? widget.image;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Image Details'),
        actions: [
          IconButton(
            icon: Icon(
              currentImage.isFavorite ? Icons.favorite : Icons.favorite_border,
              color: currentImage.isFavorite ? Colors.red : null,
            ),
            onPressed: () {
              ref.read(galleryProvider.notifier).toggleFavorite(currentImage);
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            onPressed: () {
              // TODO: Implement share functionality
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Hero(
              tag: currentImage.id,
              child: _isLoadingImage
                  ? const AspectRatio(
                      aspectRatio: 1,
                      child: Center(child: CircularProgressIndicator()),
                    )
                  : _fullImage != null
                      ? Image.memory(
                          _fullImage!,
                          fit: BoxFit.contain,
                        )
                      : const Center(child: Text('Failed to load image')),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (currentImage.caption != null) ...[
                    Text(
                      'Caption',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      currentImage.caption!,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 16),
                  ],
                  if (currentImage.isCaptionGenerating)
                    const LinearProgressIndicator()
                  else if (currentImage.caption == null)
                    const Text(
                      'Caption is being generated in the background...',
                      style: TextStyle(fontStyle: FontStyle.italic),
                    ),
                  if (currentImage.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Tags',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: currentImage.tags
                          .map(
                            (tag) => Chip(
                              label: Text(tag),
                              onDeleted: () {
                                // TODO: Implement tag deletion
                              },
                            ),
                          )
                          .toList(),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

