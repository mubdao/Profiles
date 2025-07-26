function operator(proxies = [], targetPlatform, context) {
  const letterMap = {
    'a': 'ᴀ', 'A': 'ᴀ',
    'b': 'ʙ', 'B': 'ʙ',
    'c': 'ᴄ', 'C': 'ᴄ',
    'd': 'ᴅ', 'D': 'ᴅ',
    'e': 'ᴇ', 'E': 'ᴇ',
    'f': 'ꜰ', 'F': 'ꜰ',
    'g': 'ɢ', 'G': 'ɢ',
    'h': 'ʜ', 'H': 'ʜ',
    'i': 'ɪ', 'I': 'ɪ',
    'j': 'ᴊ', 'J': 'ᴊ',
    'k': 'ᴋ', 'K': 'ᴋ',
    'l': 'ʟ', 'L': 'ʟ',
    'm': 'ᴍ', 'M': 'ᴍ',
    'n': 'ɴ', 'N': 'ɴ',
    'o': 'ᴏ', 'O': 'ᴏ',
    'p': 'ᴘ', 'P': 'ᴘ',
    'q': 'ǫ', 'Q': 'ǫ',
    'r': 'ʀ', 'R': 'ʀ',
    's': 'ꜱ', 'S': 'ꜱ',
    't': 'ᴛ', 'T': 'ᴛ',
    'u': 'ᴜ', 'U': 'ᴜ',
    'v': 'ᴠ', 'V': 'ᴠ',
    'w': 'ᴡ', 'W': 'ᴡ',
    'x': 'x', 'X': 'x',
    'y': 'ʏ', 'Y': 'ʏ',
    'z': 'ᴢ', 'Z': 'ᴢ'
  };
  const numberMap = {
    '0': '𝟢',
    '1': '𝟣',
    '2': '𝟤',
    '3': '𝟥',
    '4': '𝟦',
    '5': '𝟧',
    '6': '𝟨',
    '7': '𝟩',
    '8': '𝟪',
    '9': '𝟫'
  };
  const charMap = { ...letterMap, ...numberMap };
  function replaceChars(str) {
    if (!str) return str;
    return str.replace(/[a-zA-Z0-9]/g, match => charMap[match] || match);
  }
  console.log('上下文：', JSON.stringify(context, null, 2));
  console.log('输入节点数：', proxies.length);
  console.log('目标平台：', targetPlatform);
  proxies.forEach((proxy, index) => {
    if (proxy.name) {
      console.log(`节点 ${index} 原始名称：`, proxy.name);
      proxy.name = replaceChars(proxy.name);
      console.log(`节点 ${index} 替换后名称：`, proxy.name);
    } else {
      console.log(`节点 ${index} 无名称，跳过`);
    }
  });
  return proxies;
}
