/// Maps a file path to the MIME type Android's share sheet expects.
///
/// share_plus falls back to `application/octet-stream` when no type is given,
/// and many targets (WhatsApp, Telegram, Gmail, Bluetooth, Drive) hide
/// themselves for that generic type. Passing a real video/* or audio/* type
/// is what makes the full list of apps show up.
String mimeTypeForPath(String path) {
  final dot = path.lastIndexOf('.');
  if (dot == -1) return 'application/octet-stream';
  final ext = path.substring(dot + 1).toLowerCase();

  const video = <String, String>{
    'mp4': 'video/mp4',
    'm4v': 'video/x-m4v',
    'mkv': 'video/x-matroska',
    'webm': 'video/webm',
    'avi': 'video/x-msvideo',
    'mov': 'video/quicktime',
    'wmv': 'video/x-ms-wmv',
    'flv': 'video/x-flv',
    '3gp': 'video/3gpp',
    '3g2': 'video/3gpp2',
    'ts': 'video/mp2t',
    'mts': 'video/mp2t',
    'm2ts': 'video/mp2t',
    'mpg': 'video/mpeg',
    'mpeg': 'video/mpeg',
    'm2v': 'video/mpeg',
    'vob': 'video/dvd',
    'ogv': 'video/ogg',
    'rm': 'application/vnd.rn-realmedia',
    'rmvb': 'application/vnd.rn-realmedia-vbr',
    'divx': 'video/divx',
    'f4v': 'video/x-f4v',
    'asf': 'video/x-ms-asf',
  };

  const audio = <String, String>{
    'mp3': 'audio/mpeg',
    'aac': 'audio/aac',
    'm4a': 'audio/mp4',
    'm4b': 'audio/mp4',
    'flac': 'audio/flac',
    'wav': 'audio/wav',
    'ogg': 'audio/ogg',
    'oga': 'audio/ogg',
    'opus': 'audio/opus',
    'wma': 'audio/x-ms-wma',
    'aiff': 'audio/aiff',
    'aif': 'audio/aiff',
    'mka': 'audio/x-matroska',
    'ac3': 'audio/ac3',
    'amr': 'audio/amr',
    'mid': 'audio/midi',
    'midi': 'audio/midi',
  };

  const subtitles = <String, String>{
    'srt': 'application/x-subrip',
    'ass': 'text/x-ssa',
    'ssa': 'text/x-ssa',
    'vtt': 'text/vtt',
    'sub': 'text/plain',
  };

  return video[ext] ??
      audio[ext] ??
      subtitles[ext] ??
      // Unknown container: still declare it as video so player apps appear.
      'video/*';
}
