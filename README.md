# react-native-rtspplayer

A `<RtspPlayer>` component for react-native  
using ffmpeg,convert yuv to rgb for uiimage


![播放器例子](1.png)

### Add it to your project

Run `npm install react-native-rtspplayer --save`

#### iOS

- Install [rnpm](https://github.com/rnpm/rnpm) and run `rnpm link react-native-rtspplayer`


## Usage


```
<RtspPlayer
        ref='player'
        paused={this.state.paused}
        style={[styles.vlcplayer,this.state.customStyle]}
        source={{uri:this.props.uri,useTcp:true,width:playerDefaultWidth,height:210}}
         />
 
```


## Static Methods


`snapshot(path)`

```
this.refs['rtspplayer'].snapshot(path); //保存截图
```

## Examples

- `npm install`   
- `rnpm link`  
- 同时需要安装`ART`   
参考https://github.com/oblador/react-native-vector-icons

可以根据自己的情况使用下面的例子，自己DIY播放器  
- `<SimpleVideo />` 一个简单的播放器  


## TODOS

- [ ] Add support for Android
- [x] Add support for snapshot



## 加入ReactNative讨论组  
  
###`QQ群：316434159`  ###
![扫描加入][1]

[1]:ReactNative_qq_group.png

---

**MIT Licensed**
