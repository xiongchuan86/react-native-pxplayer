import React from 'react';
import ReactNative from 'react-native';

const {
  Component,
  PropTypes,
} = React;

const {
  StyleSheet,
  requireNativeComponent,
  NativeModules,
  View,
} = ReactNative;

export default class RtspPlayer extends Component {

  constructor(props, context) {
    super(props, context);
    this.snapshot = this.snapshot.bind(this);
    this.fullscreen = this.fullscreen.bind(this);
    this._assignRoot = this._assignRoot.bind(this);
    this._onError = this._onError.bind(this);
    this._onStartPlay = this._onStartPlay.bind(this);
    this._onBuffering = this._onBuffering.bind(this);
    this._onPlaying = this._onPlaying.bind(this);
    this._onStopped = this._onStopped.bind(this);
    this._onPaused = this._onPaused.bind(this);
  }

  setNativeProps(nativeProps) {
    this._root.setNativeProps(nativeProps);
  }

  snapshot(path) {
    this.setNativeProps({ snapshotPath:  path});
  }

  fullscreen(isFull) {
    this.setNativeProps({fullscreen:isFull});
  }

  _assignRoot(component) {
    this._root = component;
  }

  _onError(event) {
    if (this.props.onError) {
      this.props.onError(event.nativeEvent);
    }
  }

  _onStopped(event) {
    if (this.props.onStopped) {
      this.props.onStopped(event.nativeEvent);
    }
  }

  _onPaused(event) {
    if (this.props.onPaused) {
      this.props.onPaused(event.nativeEvent);
    }
  }

  _onStartPlay(event) {
    if (this.props.onStartPlay) {
      this.props.onStartPlay(event.nativeEvent);
    }
  }

  _onBuffering(event) {
    if (this.props.onBuffering) {
      this.props.onBuffering(event.nativeEvent);
    }
  }

  _onPlaying(event) {
    if (this.props.onPlaying) {
      this.props.onPlaying(event.nativeEvent);
    }
  }

  render() {
    const {
      source
    } = this.props;
    source.initOptions = source.initOptions || [];
    const nativeProps = Object.assign({}, this.props);
    Object.assign(nativeProps, {
      style: [styles.base, nativeProps.style],
      source: source,
      onVideoError: this._onError,
      onVideoStartPlay:this._onStartPlay,
      onVideoBuffering:this._onBuffering,
      onVideoPlaying:this._onPlaying,
      onVideoPaused:this._onPaused,
      onVideoStopped:this._onStopped,
    });

    return (
      <PxPlayer ref={this._assignRoot} {...nativeProps} />
    );
  }


}

RtspPlayer.propTypes = {
  /* Native only */
  snapshotPath: PropTypes.string,
  paused: PropTypes.bool,
  fullscreen: PropTypes.bool,


  /* Wrapper component */
  source: PropTypes.object,

  onError: PropTypes.func,
  onStopped: PropTypes.func,
  onStartPlay: PropTypes.func,
  onPlaying: PropTypes.func,
  onBuffering: PropTypes.func,
  onPaused: PropTypes.func,

  /* Required by react-native */
  scaleX: React.PropTypes.number,
  scaleY: React.PropTypes.number,
  translateX: React.PropTypes.number,
  translateY: React.PropTypes.number,
  rotation: React.PropTypes.number,
  ...View.propTypes,
};

const styles = StyleSheet.create({
  base: {
    overflow: 'hidden',
  }
});
const PxPlayer = requireNativeComponent('PxPlayer', RtspPlayer);
