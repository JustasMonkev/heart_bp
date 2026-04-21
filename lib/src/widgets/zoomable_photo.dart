import 'dart:io';

import 'package:flutter/material.dart';

import '../navigation/heart_page_route.dart';

class ZoomablePhoto extends StatelessWidget {
  const ZoomablePhoto({
    super.key,
    required this.imagePath,
    required this.height,
    required this.borderRadius,
    required this.fit,
    required this.semanticLabel,
  });

  final String imagePath;
  final double height;
  final BorderRadius borderRadius;
  final BoxFit fit;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: borderRadius,
        onTap: () {
          Navigator.of(context).push(
            buildHeartRoute<void>(
              builder: (_) => _PhotoViewerScreen(
                imagePath: imagePath,
                semanticLabel: semanticLabel,
              ),
            ),
          );
        },
        child: Ink(
          height: height,
          decoration: BoxDecoration(borderRadius: borderRadius),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ClipRRect(
                borderRadius: borderRadius,
                child: Image.file(
                  File(imagePath),
                  fit: fit,
                  errorBuilder: (context, error, stackTrace) {
                    return DecoratedBox(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainerHighest,
                        borderRadius: borderRadius,
                      ),
                      child: const Center(child: Text('Photo unavailable')),
                    );
                  },
                ),
              ),
              Positioned(
                right: 12,
                bottom: 12,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: const Padding(
                    padding: EdgeInsets.all(8),
                    child: Icon(Icons.zoom_in, color: Colors.white),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PhotoViewerScreen extends StatelessWidget {
  const _PhotoViewerScreen({
    required this.imagePath,
    required this.semanticLabel,
  });

  final String imagePath;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Photo'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: InteractiveViewer(
        minScale: 1,
        maxScale: 5,
        child: Center(
          child: Image.file(
            File(imagePath),
            semanticLabel: semanticLabel,
            fit: BoxFit.contain,
            errorBuilder: (context, error, stackTrace) {
              return const Text(
                'Photo unavailable',
                style: TextStyle(color: Colors.white),
              );
            },
          ),
        ),
      ),
    );
  }
}
