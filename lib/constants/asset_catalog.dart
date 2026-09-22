/// 内置图片与音效清单。
///
/// v2.x 把清单硬编码在页面里且存在重复项（`muyu` 出现 3 次、`shuidi` 出现 2 次），
/// 这里去重后集中维护。清单必须与 `assets/` 目录实际文件一致，
/// 缺失会让资源加载在运行时抛异常，因此有对应的完整性测试兜底。
///
/// 两套路径的规则不同，不要混用：
/// - `Image.asset` 需要完整 asset key（含 `assets/` 前缀），见 [imagePath]；
/// - `audioplayers` 的 `AssetSource` 会自己补上 `assets/` 前缀，
///   所以传入的必须是相对 `assets/` 的路径，见 [audioAssetPath]。
class AssetCatalog {
  const AssetCatalog._();

  /// `Image.asset` 使用的图片目录（完整 asset key 前缀）
  static const String imageDir = 'assets/images';

  /// 音效相对 `assets/` 的目录名
  static const String audioAssetDir = 'audio';

  /// 可作为木鱼皮肤的内置图片（不含二维码等展示用图）
  static const List<String> imageNames = <String>[
    'muyu',
    'bagua',
    'bug',
    'car',
    'code',
    'ddog',
    'def',
    'eat',
    'fang',
    'fish',
    'fishs',
    'game',
    'good',
    'goods',
    'hearts',
    'herat',
    'hhh',
    'home',
    'hongbao',
    'idea',
    'jing',
    'love',
    'mb',
    'mooy',
    'moyu',
    'music',
    'no',
    'pass',
    'phone',
    'qianbao',
    'qing',
    'qq',
    'rigthfish',
    'school',
    'shop',
    'sleep',
    'sui',
    'wechat',
    'wh',
    'xiao',
    'xiaochou',
    'zbad',
  ];

  /// 内置音效：资源文件名 -> 展示名
  ///
  /// 键不带目录与扩展名，统一由 [audioAssetPath] 拼接。
  static const Map<String, String> builtinSounds = <String, String>{
    'muyu': '低沉（默认）',
    'qingcui': '清脆',
    'qingzui': '轻啄',
    'shuidi': '水滴',
    'qipao': '气泡',
    'ding': '~~叮~',
    'dingdong': '叮咚',
    'dong': '咚~',
    'okay': 'okay',
    'wow': 'wow',
    'miao': '喵~~',
    'yang': '咩~~',
    'mou': '哞~~',
    'lu': '驴叫',
    'hang': '打鼾',
    'ah': '啊哈',
    'gee': '只因',
    'ngm': '你干嘛',
    'jingya': '惊讶',
    'jieya': '解压',
    'jiaochuan': '娇喘',
    'feipan': '飞盘',
    'fenpi': '放屁',
    'error': '卡带',
  };

  /// 默认音效文件名
  static const String defaultSound = 'muyu';

  /// 图片的完整 asset key，可直接传给 `Image.asset`
  static String imagePath(String name) => '$imageDir/$name.png';

  /// 音效路径，可直接传给 `AssetSource`（**不含** `assets/` 前缀）
  ///
  /// 入参兼容三种写法：`muyu`、`audio/muyu.mp3`、`assets/audio/muyu.mp3`，
  /// 因此 v2 存下来的历史值可以直接读。
  static String audioAssetPath(String nameOrPath) =>
      '$audioAssetDir/${soundNameFromAsset(nameOrPath)}.mp3';

  /// 音效在工程里的真实文件路径，仅供测试校验文件是否存在
  static String audioFilePath(String name) =>
      'assets/$audioAssetDir/${soundNameFromAsset(name)}.mp3';

  /// 从任意写法中反解出音效文件名（`muyu`）
  static String soundNameFromAsset(String asset) {
    var name = asset.trim();
    const withAssets = 'assets/$audioAssetDir/';
    const withAudio = '$audioAssetDir/';
    if (name.startsWith(withAssets)) {
      name = name.substring(withAssets.length);
    } else if (name.startsWith(withAudio)) {
      name = name.substring(withAudio.length);
    }
    if (name.endsWith('.mp3')) {
      name = name.substring(0, name.length - '.mp3'.length);
    }
    return name;
  }

  static String get defaultAudioAsset => audioAssetPath(defaultSound);
}