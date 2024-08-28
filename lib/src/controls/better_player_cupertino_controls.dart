import 'dart:async';
import 'package:better_player/src/configuration/better_player_controls_configuration.dart';
import 'package:better_player/src/controls/better_player_controls_state.dart';
import 'package:better_player/src/controls/better_player_cupertino_progress_bar.dart';
import 'package:better_player/src/controls/better_player_multiple_gesture_detector.dart';
import 'package:better_player/src/controls/better_player_progress_colors.dart';
import 'package:better_player/src/core/better_player_controller.dart';
import 'package:better_player/src/core/better_player_utils.dart';
import 'package:better_player/src/video_player/video_player.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BetterPlayerCupertinoControls extends StatefulWidget {
  ///Callback used to send information if player bar is hidden or not
  final Function(bool visbility) onControlsVisibilityChanged;

  ///Controls config
  final BetterPlayerControlsConfiguration controlsConfiguration;

  const BetterPlayerCupertinoControls({
    required this.onControlsVisibilityChanged,
    required this.controlsConfiguration,
    Key? key,
  }) : super(key: key);

  @override
  State<StatefulWidget> createState() {
    return _BetterPlayerCupertinoControlsState();
  }
}

class _BetterPlayerCupertinoControlsState extends BetterPlayerControlsState<BetterPlayerCupertinoControls> with SingleTickerProviderStateMixin {
  // ios
  final marginSize = 5.0;
  VideoPlayerValue? _latestValue;
  double? _latestVolume;
  Timer? _hideTimer;
  Timer? _expandCollapseTimer;
  Timer? _initTimer;
  bool _wasLoading = false;
  late AnimationController _showChatController;
  late Animation<Offset> _offsetAnimation;

  @override
  void initState() {
    super.initState();
    _showChatController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _offsetAnimation = Tween<Offset>(
      begin: const Offset(2, 0.0), // Offscreen right
      end: Offset.zero, // Onscreen
    ).animate(CurvedAnimation(parent: _showChatController, curve: Curves.fastEaseInToSlowEaseOut));
  }


  VideoPlayerController? _controller;
  BetterPlayerController? _betterPlayerController;
  StreamSubscription? _controlsVisibilityStreamSubscription;

  BetterPlayerControlsConfiguration get _controlsConfiguration => widget.controlsConfiguration;

  @override
  VideoPlayerValue? get latestValue => _latestValue;

  @override
  BetterPlayerController? get betterPlayerController => _betterPlayerController;

  @override
  BetterPlayerControlsConfiguration get betterPlayerControlsConfiguration => _controlsConfiguration;

  @override
  Widget build(BuildContext context) {
    return buildLTRDirectionality(_buildMainWidget());
  }

  ///Builds main widget of the controls.
  Widget _buildMainWidget() {
    _betterPlayerController = BetterPlayerController.of(context);

    if (_latestValue?.hasError == true) {
      return Container(
        color: Colors.black,
        child: _buildErrorWidget(),
      );
    }

    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;
    final backgroundColor = Colors.transparent;
    final iconColor = Colors.white;
    final orientation = MediaQuery
        .of(context)
        .orientation;
    final barHeight = orientation == Orientation.portrait ? _controlsConfiguration.controlBarHeight : _controlsConfiguration.controlBarHeight + 10;
    const buttonPadding = 14.0;
    final isFullScreen = _betterPlayerController?.isFullScreen == true;

    _wasLoading = isLoading(_latestValue);
    final controlsColumn = Column(children: <Widget>[
      _buildTopBar(
        backgroundColor,
        iconColor,
        barHeight,
        buttonPadding,
      ),
      if (_wasLoading) Expanded(child: Center(child: _buildLoadingWidget())) else
        _buildHitArea(),
      // _buildNextVideoWidget(),
      _buildBottomBar(
        backgroundColor,
        iconColor,
        barHeight,
      ),
    ]);
    return GestureDetector(
      onTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onTap?.call();
        }
        controlsNotVisible ? cancelAndRestartTimer() : changePlayerControlsNotVisible(true);
      },
      onDoubleTap: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onDoubleTap?.call();
        }
        cancelAndRestartTimer();
        _onPlayPause();
      },
      onLongPress: () {
        if (BetterPlayerMultipleGestureDetector.of(context) != null) {
          BetterPlayerMultipleGestureDetector.of(context)!.onLongPress?.call();
        }
      },
      child: isFullScreen ? Stack(children: [
        (_betterPlayerController!.isHidechart && _betterPlayerController!.isFullScreen)?
        Positioned(right: 40,
            child: Visibility(
                visible: _betterPlayerController!.isHidechart, child: SlideTransition(position: _offsetAnimation, child: Container(
              height: MediaQuery.of(context).size.height,
              width: MediaQuery.of(context).size.width * 0.25,
              color: Colors.transparent, child: AbsorbPointer(absorbing: false ,child:_controlsConfiguration.customControlschat),
            ),)
            )) : SizedBox(),
        AbsorbPointer(absorbing: false, child: controlsColumn),
      ]) : controlsColumn,
    );
  }

  @override
  void dispose() {
    _dispose();
    super.dispose();
  }

  void _dispose() {
    _controller!.removeListener(_updateState);
    _hideTimer?.cancel();
    _expandCollapseTimer?.cancel();
    _initTimer?.cancel();
    _controlsVisibilityStreamSubscription?.cancel();
  }

  @override
  void didChangeDependencies() {
    final _oldController = _betterPlayerController;
    _betterPlayerController = BetterPlayerController.of(context);
    _controller = _betterPlayerController!.videoPlayerController;

    if (_oldController != _betterPlayerController) {
      _dispose();
      _initialize();
    }

    super.didChangeDependencies();
  }

  Widget _buildBottomBar(Color backgroundColor,
      Color iconColor,
      double barHeight,) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    return Container(
      alignment: Alignment.bottomCenter,
      margin: EdgeInsets.all(marginSize),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Container(
          height: barHeight,
          decoration: BoxDecoration(
            color: backgroundColor,
          ),
          child: _betterPlayerController!.isLiveStream()
              ? AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              onEnd: _onPlayerHide,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  const SizedBox(width: 8),
                  if (_controlsConfiguration.enablePlayPause) _buildPlayPause(_controller!, iconColor, barHeight) else
                    const SizedBox(),
                  const SizedBox(width: 8),
                  _buildLiveWidget(),
                ],
              ))
              : Row(
            children: <Widget>[
              if (_controlsConfiguration.enablePlayPause) _buildPlayPause(_controller!, iconColor, barHeight) else
                const SizedBox(),
              if (_controlsConfiguration.enableMute)_buildMuteButton(_controller, backgroundColor, iconColor, barHeight, 20, 10,) else
                const SizedBox(),
              if (_controlsConfiguration.enableProgressText) _buildPosition() else
                const SizedBox(),
              if (_controlsConfiguration.enableProgressBar && _betterPlayerController!.isFullScreen) _buildProgressBar() else
                const SizedBox(),
              // if (_controlsConfiguration.enableOverflowMenu) _buildRemaining() else const SizedBox(),
              _betterPlayerController!.isFullScreen ? const SizedBox() : Spacer(),
              if (_controlsConfiguration.enableFullscreen && !_betterPlayerController!.isFullScreen)
                _buildExpandButton(
                  backgroundColor,
                  iconColor,
                  barHeight,
                  20,
                  6,
                )
              else
                _buildHidechat(
                  backgroundColor,
                  iconColor,
                  barHeight,
                  20,
                  20,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLiveWidget() {
    return Expanded(
      child: Text(
        _betterPlayerController!.translations.controlsLive,
        style: TextStyle(color: _controlsConfiguration.liveTextColor, fontWeight: FontWeight.bold),
      ),
    );
  }

  GestureDetector _buildExpandButton(Color backgroundColor,
      Color iconColor,
      double barHeight,
      double iconSize,
      double buttonPadding,) {
    return GestureDetector(
      onTap: _onExpandCollapse,
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Container(
            height: barHeight,
            padding: EdgeInsets.symmetric(
              horizontal: buttonPadding,
            ),
            decoration: BoxDecoration(color: backgroundColor),
            child: Center(
              child: Icon(
                _betterPlayerController!.isFullScreen ? _controlsConfiguration.fullscreenDisableIcon : _controlsConfiguration.fullscreenEnableIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  InkWell _buildHidechat(Color backgroundColor,
      Color iconColor,
      double barHeight,
      double iconSize,
      double buttonPadding,) {
    return InkWell(
      onTap: _onHide,
      child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: _betterPlayerController!.isHidechart ? _controlsConfiguration.showChatIcon :_controlsConfiguration.hideChatIcon),
    );
  }

  Expanded _buildHitArea() {
    return Expanded(
      child: GestureDetector(
        onTap: _latestValue != null && _latestValue!.isPlaying
            ? () {
          if (controlsNotVisible == true) {
            cancelAndRestartTimer();
          } else {
            _hideTimer?.cancel();
            changePlayerControlsNotVisible(true);
          }
        } : () {
          _hideTimer?.cancel();
          changePlayerControlsNotVisible(false);
        },
        child: Container(
          color: Colors.transparent,
        ),
      ),
    );
  }

  GestureDetector _buildMoreButton(VideoPlayerController? controller,
      Color backgroundColor,
      Color iconColor,
      double barHeight,
      double iconSize,
      double buttonPadding,) {
    return GestureDetector(
      onTap: () {
        onShowMoreClicked();
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                _controlsConfiguration.overflowMenuIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildMuteButton(VideoPlayerController? controller,
      Color backgroundColor,
      Color iconColor,
      double barHeight,
      double iconSize,
      double buttonPadding,) {
    return GestureDetector(
      onTap: () {
        cancelAndRestartTimer();

        if (_latestValue!.volume == 0) {
          controller!.setVolume(_latestVolume ?? 0.5);
        } else {
          _latestVolume = controller!.value.volume;
          controller.setVolume(0.0);
        }
      },
      child: AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10.0),
          child: Container(
            decoration: BoxDecoration(
              color: backgroundColor,
            ),
            child: Container(
              height: barHeight,
              padding: EdgeInsets.symmetric(
                horizontal: buttonPadding,
              ),
              child: Icon(
                (_latestValue != null && _latestValue!.volume > 0) ? _controlsConfiguration.muteIcon : _controlsConfiguration.unMuteIcon,
                color: iconColor,
                size: iconSize,
              ),
            ),
          ),
        ),
      ),
    );
  }

  GestureDetector _buildPlayPause(VideoPlayerController controller,
      Color iconColor,
      double barHeight,) {
    return GestureDetector(
      onTap: _onPlayPause,
      child: AnimatedOpacity(
          opacity: controlsNotVisible ? 0.0 : 1.0,
          duration: _controlsConfiguration.controlsHideTime,
          child: Container(
            height: barHeight,
            color: Colors.transparent,
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Icon(
              controller.value.isPlaying ? _controlsConfiguration.pauseIcon : _controlsConfiguration.playIcon,
              color: iconColor,
              size: barHeight * 0.6,
            ),
          )),
    );
  }

  Widget _buildPosition() {
    final position = _latestValue != null ? _latestValue!.position : const Duration();
    return AnimatedOpacity(
        opacity: controlsNotVisible ? 0.0 : 1.0,
        duration: _controlsConfiguration.controlsHideTime,
        child: Padding(
          padding: const EdgeInsets.only(right: 12.0),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.all(Radius.circular(4.0)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: _controlsConfiguration.textColor,
                        fontSize: 12.0,
                      ),
                    ),
                    Text(
                      'LIVE',
                      style: TextStyle(
                        color: _controlsConfiguration.textColor,
                        fontSize: 12.0,
                      ),
                    ),
                    SizedBox(width: 5,),
                  ],),),
              SizedBox(width: 5,),
              Row(children: [
                Icon(_controlsConfiguration.eyeWatchingIcon, color: _controlsConfiguration.textColor,),
                SizedBox(width: 5,),
                Text(
                  '${_controlsConfiguration.numberWatching}',
                  style: TextStyle(
                    color: _controlsConfiguration.textColor,
                    fontSize: 12.0,
                  ),
                )
              ],),
            ],
          ),
        ));
  }

  Widget _buildRemaining() {
    final position = _latestValue != null && _latestValue!.duration != null ? _latestValue!.duration! - _latestValue!.position : const Duration();

    return Padding(
      padding: const EdgeInsets.only(right: 12.0),
      child: Text(
        '-${BetterPlayerUtils.formatDuration(position)}',
        style: TextStyle(color: _controlsConfiguration.textColor, fontSize: 12.0),
      ),
    );
  }

  GestureDetector _buildSkipBack(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipBack,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: const EdgeInsets.only(left: 10.0),
        padding: const EdgeInsets.symmetric(
          horizontal: 8,
        ),
        child: Icon(
          _controlsConfiguration.skipBackIcon,
          color: iconColor,
          size: barHeight * 0.4,
        ),
      ),
    );
  }

  // tiêu đề của video

  GestureDetector _buildTittle(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: _backtittle,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        margin: EdgeInsets.only(
          top: marginSize,
          right: marginSize,
          left: marginSize,
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              _controlsConfiguration.backIcon,
              color: iconColor,
              size: barHeight * 0.6,
            ),
            Text(
              '${_controlsConfiguration.textTitle}',
              style: TextStyle(color: _controlsConfiguration.textColortitle),
            )
          ],
        ),
      ),
    );
  }

  GestureDetector _buildSkipForward(Color iconColor, double barHeight) {
    return GestureDetector(
      onTap: skipForward,
      child: Container(
        height: barHeight,
        color: Colors.transparent,
        padding: const EdgeInsets.symmetric(horizontal: 6),
        margin: const EdgeInsets.only(right: 8.0),
        child: Icon(
          _controlsConfiguration.skipForwardIcon,
          color: iconColor,
          size: barHeight * 0.4,
        ),
      ),
    );
  }

  Widget _buildTopBar(Color backgroundColor,
      Color iconColor,
      double topBarHeight,
      double buttonPadding,) {
    if (!betterPlayerController!.controlsEnabled) {
      return const SizedBox();
    }
    final barHeight = topBarHeight * 0.8;
    final iconSize = topBarHeight * 0.4;

    return AnimatedOpacity(
      opacity: controlsNotVisible ? 0.0 : 1.0,
      duration: _controlsConfiguration.controlsHideTime,
      onEnd: _onPlayerHide,
      child: Container(
        height: barHeight,
        margin: EdgeInsets.only(
          top: _betterPlayerController!.isFullScreen ? 20 : marginSize,
          right: marginSize,
          left: marginSize,
        ),
        child: Row(
          children: <Widget>[
            if (_controlsConfiguration.enableTittle && _betterPlayerController!.isFullScreen) _buildTittle(iconColor, barHeight) else
              const SizedBox(),
            const Spacer(),
            // const SizedBox(
            //   width: 4,
            // ),
            // if (_controlsConfiguration.enableOverflowMenu)
            //   _buildMoreButton(
            //     _controller,
            //     backgroundColor,
            //     iconColor,
            //     barHeight,
            //     iconSize,
            //     buttonPadding,
            //   )
            // else
            //   const SizedBox(),
          ],
        ),
      ),
    );
  }

  Widget _buildNextVideoWidget() {
    return StreamBuilder<int?>(
      stream: _betterPlayerController!.nextVideoTimeStream,
      builder: (context, snapshot) {
        final time = snapshot.data;
        if (time != null && time > 0) {
          return InkWell(
            onTap: () {
              _betterPlayerController!.playNextVideo();
            },
            child: Align(
              alignment: Alignment.bottomRight,
              child: Container(
                margin: const EdgeInsets.only(bottom: 4, right: 8),
                decoration: BoxDecoration(
                  color: _controlsConfiguration.controlBarColor,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    "${_betterPlayerController!.translations.controlsNextVideoIn} $time ...",
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }

  @override
  void cancelAndRestartTimer() {
    _hideTimer?.cancel();
    changePlayerControlsNotVisible(false);
    _startHideTimer();
  }

  @override
  void changerchat() {
    changePlayerControlsNotVisible(false);
  }

  Future<void> _initialize() async {
    _controller!.addListener(_updateState);

    _updateState();

    if ((_controller!.value.isPlaying) || _betterPlayerController!.betterPlayerConfiguration.autoPlay) {
      _startHideTimer();
    }

    if (_controlsConfiguration.showControlsOnInitialize) {
      _initTimer = Timer(const Duration(milliseconds: 200), () {
        changePlayerControlsNotVisible(false);
      });
    }
    _controlsVisibilityStreamSubscription = _betterPlayerController!.controlsVisibilityStream.listen((state) {
      changePlayerControlsNotVisible(!state);

      if (!controlsNotVisible) {
        cancelAndRestartTimer();
      }
    });
  }

  void _onExpandCollapse() {
    changePlayerControlsNotVisible(true);
    _betterPlayerController!.toggleFullScreen();
    _expandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
      setState(() {
        cancelAndRestartTimer();
      });
    });
  }

  void _onHide() {
    if(_betterPlayerController!.isHidechart) {
      _showChatController.reverse().then((_) {
        _betterPlayerController!.toggleHideChat();
      });

    }
    else {
      _betterPlayerController!.toggleHideChat();
      _showChatController.forward();
    }
  }

  void _backtittle() {
    if (_betterPlayerController!.isFullScreen) {
      changePlayerControlsNotVisible(true);
      _betterPlayerController!.toggleFullScreen();
      _expandCollapseTimer = Timer(_controlsConfiguration.controlsHideTime, () {
        setState(() {
          cancelAndRestartTimer();
        });
      });
    } else {
      Navigator.of(context, rootNavigator: false).pop();
    }
  }

  Widget _buildProgressBar() {
    return Expanded(
      child: InkWell(
        onTap: () {
          showModalBottomSheet<void>(
            isScrollControlled: true,
            context: context,
            constraints: BoxConstraints(
              maxWidth: MediaQuery
                  .of(context)
                  .size
                  .width,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(0),
                  topRight: Radius.circular(0)),
            ),
            builder: (BuildContext context) {
              return Padding(
                  padding: MediaQuery
                      .of(context)
                      .viewInsets,
                  child: SafeArea(child: _controlsConfiguration.chatVideo,));
            },
          );
        },
        child: AnimatedOpacity(
            opacity: controlsNotVisible ? 0.0 : 1.0,
            duration: _controlsConfiguration.controlsHideTime,
            child: Padding(
              padding: const EdgeInsets.only(right: 12.0),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.grey[600],
                  borderRadius: BorderRadius.all(Radius.circular(16.0)),
                ),
                child: Padding(
                  padding: EdgeInsets.all(6),
                  child: Text('${_controlsConfiguration.textHint}', style: TextStyle(color: Colors.grey[200], fontSize: 10), maxLines: 1,),
                ),
              ),
            )),),
    );
  }

  void _onPlayPause() {
    bool isFinished = false;

    if (_latestValue?.position != null && _latestValue?.duration != null) {
      isFinished = _latestValue!.position >= _latestValue!.duration!;
    }

    if (_controller!.value.isPlaying) {
      changePlayerControlsNotVisible(false);
      _hideTimer?.cancel();
      _betterPlayerController!.pause();
    } else {
      cancelAndRestartTimer();

      if (!_controller!.value.initialized) {
        if (_betterPlayerController!.betterPlayerDataSource?.liveStream == true) {
          _betterPlayerController!.play();
          _betterPlayerController!.cancelNextVideoTimer();
        }
      } else {
        if (isFinished) {
          _betterPlayerController!.seekTo(const Duration());
        }
        _betterPlayerController!.play();
        _betterPlayerController!.cancelNextVideoTimer();
      }
    }
  }

  void _startHideTimer() {
    if (_betterPlayerController!.controlsAlwaysVisible) {
      return;
    }
    _hideTimer = Timer(const Duration(seconds: 3), () {
      changePlayerControlsNotVisible(true);
    });
  }

  void _updateState() {
    if (mounted) {
      if (!controlsNotVisible || isVideoFinished(_controller!.value) || _wasLoading || isLoading(_controller!.value)) {
        setState(() {
          _latestValue = _controller!.value;
          if (isVideoFinished(_latestValue)) {
            changePlayerControlsNotVisible(false);
          }
        });
      }
    }
  }

  void _onPlayerHide() {
    _betterPlayerController!.toggleControlsVisibility(!controlsNotVisible);
    widget.onControlsVisibilityChanged(!controlsNotVisible);
  }

  Widget _buildErrorWidget() {
    final errorBuilder = _betterPlayerController!.betterPlayerConfiguration.errorBuilder;
    if (errorBuilder != null) {
      return errorBuilder(context, _betterPlayerController!.videoPlayerController!.value.errorDescription);
    } else {
      final textStyle = TextStyle(color: _controlsConfiguration.textColor);
      return  Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.exclamationmark_triangle,
              color: _controlsConfiguration.iconsColor,
              size: 42,
            ),
            Text(
              _betterPlayerController!.translations.generalDefaultError,
              style: textStyle,
            ),
            if (_controlsConfiguration.enableRetry)
              TextButton(
                onPressed: () {
                  _betterPlayerController!.retryDataSource();
                },
                child: Text(
                  _betterPlayerController!.translations.generalRetry,
                  style: textStyle.copyWith(fontWeight: FontWeight.bold),
                ),
              )
          ],
        ),
      );
    }
  }

  Widget? _buildLoadingWidget() {
    if (_controlsConfiguration.loadingWidget != null) {
      return _controlsConfiguration.loadingWidget;
    }

    return CircularProgressIndicator(
      valueColor: AlwaysStoppedAnimation<Color>(_controlsConfiguration.loadingColor),
    );
  }

  Widget _buildPipButton(Color backgroundColor,
      Color iconColor,
      double barHeight,
      double iconSize,
      double buttonPadding,) {
    return FutureBuilder<bool>(
      future: _betterPlayerController!.isPictureInPictureSupported(),
      builder: (context, snapshot) {
        final isPipSupported = snapshot.data ?? false;
        if (isPipSupported && _betterPlayerController!.betterPlayerGlobalKey != null) {
          return GestureDetector(
            onTap: () {
              betterPlayerController!.enablePictureInPicture(betterPlayerController!.betterPlayerGlobalKey!);
            },
            child: AnimatedOpacity(
              opacity: controlsNotVisible ? 0.0 : 1.0,
              duration: _controlsConfiguration.controlsHideTime,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  height: barHeight,
                  padding: EdgeInsets.only(
                    left: buttonPadding,
                    right: buttonPadding,
                  ),
                  decoration: BoxDecoration(
                    color: backgroundColor.withOpacity(0.5),
                  ),
                  child: Center(
                    child: Icon(
                      _controlsConfiguration.pipMenuIcon,
                      color: iconColor,
                      size: iconSize,
                    ),
                  ),
                ),
              ),
            ),
          );
        } else {
          return const SizedBox();
        }
      },
    );
  }
}
