import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_trip/video_clip/thumbnail_viewer.dart';
import 'package:flutter_trip/video_clip/clip_editor_painter.dart';
import 'package:flutter_trip/video_clip/clipper.dart';
import 'package:video_player/video_player.dart';

class ClipEditor extends StatefulWidget {
  final Clipper clipper;

  final double viewerWidth;

  final double viewerHeight;

  final BoxFit fit;

  final Duration maxVideoLength;
  final double circleSize;

  final double borderWidth;

  final double scrubberWidth;

  final double circleSizeOnDrag;

  final Color circlePaintColor;

  final Color borderPaintColor;

  final Color scrubberPaintColor;

  final int thumbnailQuality;
  final bool showDuration;

  final TextStyle durationTextStyle;

  final Function(double startValue)? onChangeStart;

  final Function(double endValue)? onChangeEnd;

  final Function(bool isPlaying)? onChangePlaybackState;
  final int sideTapSize;

  const ClipEditor({
    Key? key,
    required this.clipper,
    this.viewerWidth = 50.0 * 8,
    this.viewerHeight = 50,
    this.fit = BoxFit.fitHeight,
    this.maxVideoLength = const Duration(milliseconds: 0),
    this.circleSize = 5.0,
    this.borderWidth = 3,
    this.scrubberWidth = 1,
    this.circleSizeOnDrag = 8.0,
    this.circlePaintColor = Colors.white,
    this.borderPaintColor = Colors.white,
    this.scrubberPaintColor = Colors.white,
    this.thumbnailQuality = 75,
    this.showDuration = true,
    this.sideTapSize = 24,
    this.durationTextStyle = const TextStyle(color: Colors.white),
    this.onChangeStart,
    this.onChangeEnd,
    this.onChangePlaybackState,
  }) : super(key: key);

  @override
  _ClipEditorState createState() => _ClipEditorState();
}

class _ClipEditorState extends State<ClipEditor> with TickerProviderStateMixin {
  File? get _videoFile => widget.clipper.currentVideoFile;

  double _videoStartPos = 0.0;
  double _videoEndPos = 0.0;

  Offset _startPos = const Offset(0, 0);
  Offset _endPos = const Offset(0, 0);

  double _startFraction = 0.0;
  double _endFraction = 1.0;

  int _videoDuration = 0;
  int _currentPosition = 0;

  double _thumbnailViewerW = 0.0;
  double _thumbnailViewerH = 0.0;

  int _numberOfThumbnails = 0;

  late double _circleSize;

  double? fraction;
  double? maxLengthPixels;

  ThumbnailViewer? thumbnailWidget;

  Animation<double>? _scrubberAnimation;
  AnimationController? _animationController;
  late Tween<double> _linearTween;

  VideoPlayerController get videoPlayerController =>
      widget.clipper.videoPlayerController!;

  EditorDragType _dragType = EditorDragType.left;

  bool _allowDrag = true;

  @override
  void initState() {
    super.initState();

    widget.clipper.eventStream.listen((event) {
      if (event == ClipperEvent.initialized) {
        //The video has been initialized, now we can load stuff

        _initializeVideoController();
        videoPlayerController.seekTo(const Duration(milliseconds: 0));
        setState(() {
          Duration totalDuration = videoPlayerController.value.duration;

          if (widget.maxVideoLength > const Duration(milliseconds: 0) &&
              widget.maxVideoLength < totalDuration) {
            if (widget.maxVideoLength < totalDuration) {
              fraction = widget.maxVideoLength.inMilliseconds /
                  totalDuration.inMilliseconds;

              maxLengthPixels = _thumbnailViewerW * fraction!;
            }
          } else {
            maxLengthPixels = _thumbnailViewerW;
          }

          _videoEndPos = fraction != null
              ? _videoDuration.toDouble() * fraction!
              : _videoDuration.toDouble();

          widget.onChangeEnd!(_videoEndPos);

          _endPos = Offset(
            maxLengthPixels != null ? maxLengthPixels! : _thumbnailViewerW,
            _thumbnailViewerH,
          );

          // Defining the tween points
          _linearTween = Tween(begin: _startPos.dx, end: _endPos.dx);
          _animationController = AnimationController(
            vsync: this,
            duration:
                Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt()),
          );

          _scrubberAnimation = _linearTween.animate(_animationController!)
            ..addListener(() {
              setState(() {});
            })
            ..addStatusListener((status) {
              if (status == AnimationStatus.completed) {
                _animationController!.stop();
              }
            });
        });
      }
    });

    _circleSize = widget.circleSize;

    _thumbnailViewerH = widget.viewerHeight;

    _numberOfThumbnails = widget.viewerWidth ~/ _thumbnailViewerH;

    _thumbnailViewerW = _numberOfThumbnails * _thumbnailViewerH;
  }

  Future<void> _initializeVideoController() async {
    if (_videoFile != null) {
      videoPlayerController.addListener(() {
        final bool isPlaying = videoPlayerController.value.isPlaying;

        if (isPlaying) {
          widget.onChangePlaybackState!(true);
          setState(() {
            _currentPosition =
                videoPlayerController.value.position.inMilliseconds;

            if (_currentPosition > _videoEndPos.toInt()) {
              videoPlayerController.pause();
              widget.onChangePlaybackState!(false);
              _animationController!.stop();
            } else {
              if (!_animationController!.isAnimating) {
                widget.onChangePlaybackState!(true);
                _animationController!.forward();
              }
            }
          });
        } else {
          if (videoPlayerController.value.isInitialized) {
            if (_animationController != null) {
              if ((_scrubberAnimation?.value ?? 0).toInt() ==
                  (_endPos.dx).toInt()) {
                _animationController!.reset();
              }
              _animationController!.stop();
              widget.onChangePlaybackState!(false);
            }
          }
        }
      });

      videoPlayerController.setVolume(1.0);
      _videoDuration = videoPlayerController.value.duration.inMilliseconds;

      final ThumbnailViewer _thumbnailWidget = ThumbnailViewer(
        videoFile: _videoFile!,
        videoDuration: _videoDuration,
        fit: widget.fit,
        thumbnailHeight: _thumbnailViewerH,
        numberOfThumbnails: _numberOfThumbnails,
        quality: widget.thumbnailQuality,
      );
      thumbnailWidget = _thumbnailWidget;
    }
  }

  void _onDragStart(DragStartDetails details) {
    debugPrint("_onDragStart");
    debugPrint(details.localPosition.toString());
    debugPrint((_startPos.dx - details.localPosition.dx).abs().toString());
    debugPrint((_endPos.dx - details.localPosition.dx).abs().toString());

    final startDifference = _startPos.dx - details.localPosition.dx;
    final endDifference = _endPos.dx - details.localPosition.dx;

    if (startDifference <= widget.sideTapSize &&
        endDifference >= -widget.sideTapSize) {
      _allowDrag = true;
    } else {
      debugPrint("Dragging is outside of frame, ignoring gesture...");
      _allowDrag = false;
      return;
    }

    //Now we determine which part is dragged
    if (details.localPosition.dx <= _startPos.dx + widget.sideTapSize) {
      _dragType = EditorDragType.left;
    } else if (details.localPosition.dx <= _endPos.dx - widget.sideTapSize) {
      _dragType = EditorDragType.center;
    } else {
      _dragType = EditorDragType.right;
    }
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!_allowDrag) return;

    _circleSize = widget.circleSizeOnDrag;

    if (_dragType == EditorDragType.left) {
      if ((_startPos.dx + details.delta.dx >= 0) &&
          (_startPos.dx + details.delta.dx <= _endPos.dx) &&
          !(_endPos.dx - _startPos.dx - details.delta.dx > maxLengthPixels!)) {
        _startPos += details.delta;
        _onStartDragged();
      }
    } else if (_dragType == EditorDragType.center) {
      if ((_startPos.dx + details.delta.dx >= 0) &&
          (_endPos.dx + details.delta.dx <= _thumbnailViewerW)) {
        _startPos += details.delta;
        _endPos += details.delta;
        _onStartDragged();
        _onEndDragged();
      }
    } else {
      if ((_endPos.dx + details.delta.dx <= _thumbnailViewerW) &&
          (_endPos.dx + details.delta.dx >= _startPos.dx) &&
          !(_endPos.dx - _startPos.dx + details.delta.dx > maxLengthPixels!)) {
        _endPos += details.delta;
        _onEndDragged();
      }
    }
    setState(() {});
  }

  void _onStartDragged() {
    _startFraction = (_startPos.dx / _thumbnailViewerW);
    _videoStartPos = _videoDuration * _startFraction;
    widget.onChangeStart!(_videoStartPos);
    _linearTween.begin = _startPos.dx;
    _animationController!.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController!.reset();
  }

  void _onEndDragged() {
    _endFraction = _endPos.dx / _thumbnailViewerW;
    _videoEndPos = _videoDuration * _endFraction;
    widget.onChangeEnd!(_videoEndPos);
    _linearTween.end = _endPos.dx;
    _animationController!.duration =
        Duration(milliseconds: (_videoEndPos - _videoStartPos).toInt());
    _animationController!.reset();
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() {
      _circleSize = widget.circleSize;
      if (_dragType == EditorDragType.right) {
        videoPlayerController
            .seekTo(Duration(milliseconds: _videoEndPos.toInt()));
      } else {
        videoPlayerController
            .seekTo(Duration(milliseconds: _videoStartPos.toInt()));
      }
    });
  }

  @override
  void dispose() {
    videoPlayerController.pause();
    widget.onChangePlaybackState!(false);
    if (_videoFile != null) {
      videoPlayerController.setVolume(0.0);
      videoPlayerController.dispose();
      widget.onChangePlaybackState!(false);
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onHorizontalDragStart: _onDragStart,
      onHorizontalDragUpdate: _onDragUpdate,
      onHorizontalDragEnd: _onDragEnd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          widget.showDuration
              ? SizedBox(
                  width: _thumbnailViewerW,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 8.0),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      mainAxisSize: MainAxisSize.max,
                      children: <Widget>[
                        Text(
                          Duration(milliseconds: _videoStartPos.toInt())
                              .toString()
                              .split('.')[0],
                          style: widget.durationTextStyle,
                        ),
                        videoPlayerController.value.isPlaying
                            ? Text(
                                Duration(milliseconds: _currentPosition.toInt())
                                    .toString()
                                    .split('.')[0],
                                style: widget.durationTextStyle,
                              )
                            : Container(),
                        Text(
                          Duration(milliseconds: _videoEndPos.toInt())
                              .toString()
                              .split('.')[0],
                          style: widget.durationTextStyle,
                        ),
                      ],
                    ),
                  ),
                )
              : Container(),
          CustomPaint(
            foregroundPainter: ClipEditorPainter(
              startPos: _startPos,
              endPos: _endPos,
              scrubberAnimationDx: _scrubberAnimation?.value ?? 0,
              circleSize: _circleSize,
              borderWidth: widget.borderWidth,
              scrubberWidth: widget.scrubberWidth,
              circlePaintColor: widget.circlePaintColor,
              borderPaintColor: widget.borderPaintColor,
              scrubberPaintColor: widget.scrubberPaintColor,
            ),
            child: Container(
              color: Colors.grey[900],
              height: _thumbnailViewerH,
              width: _thumbnailViewerW,
              child: thumbnailWidget ?? Container(),
            ),
          ),
        ],
      ),
    );
  }
}

enum EditorDragType {
  left,

  center,

  right
}
