const inArg = $arguments;
const nx = inArg.nx || false,
  bl = inArg.bl || false,
  nf = inArg.nf || false,
  key = inArg.key || false,
  blgd = inArg.blgd || false,
  blpx = inArg.blpx || false,
  blnx = inArg.blnx || false,
  numone = inArg.one || false,
  debug = inArg.debug || false,
  clear = inArg.clear || false,
  addflag = inArg.flag || false,
  nm = inArg.nm || false;

const FGF = inArg.fgf == undefined ? " " : decodeURI(inArg.fgf),
  XHFGF = inArg.sn == undefined ? " " : decodeURI(inArg.sn),
  FNAME = inArg.name == undefined ? "" : decodeURI(inArg.name),
  BLKEY = inArg.blkey == undefined ? "" : decodeURI(inArg.blkey),
  blockquic = inArg.blockquic == undefined ? "" : decodeURI(inArg.blockquic),
  nameMap = {
    cn: "cn",
    zh: "cn",
    us: "us",
    en: "us",
    quan: "quan",
    gq: "gq",
    flag: "gq",
  },
  inname = nameMap[inArg.in] || "",
  outputName = nameMap[inArg.out] || "";

// 扩展后的国家/地区列表
const FG = [
  '🇭🇰', '🇹🇼', '🇲🇴', '🇸🇬', '🇯🇵', '🇺🇸', '🇰🇷', '🇩🇪', '🇷🇺',
  // 东南亚
  '🇹🇭', '🇻🇳', '🇵🇭', '🇲🇾', '🇮🇩', '🇰🇭', '🇱🇦', '🇲🇲', '🇧🇳',
  // 欧洲
  '🇬🇧', '🇫🇷', '🇳🇱', '🇮🇹', '🇪🇸', '🇨🇭', '🇸🇪', '🇳🇴', '🇵🇱', 
  '🇧🇪', '🇦🇹', '🇩🇰', '🇫🇮', '🇮🇪', '🇵🇹', '🇬🇷', '🇨🇿', '🇷🇴',
  // 北美
  '🇨🇦', '🇲🇽',
  // 南美
  '🇧🇷', '🇦🇷', '🇨🇱', '🇨🇴',
  // 大洋洲
  '🇦🇺', '🇳🇿',
  // 中东
  '🇦🇪', '🇸🇦', '🇹🇷', '🇮🇱',
  // 非洲
  '🇿🇦', '🇪🇬',
  // 亚洲其他
  '🇮🇳', '🇵🇰'
];

const EN = [
  'HK', 'TW', 'MO', 'SG', 'JP', 'US', 'KR', 'DE', 'RU',
  // 东南亚
  'TH', 'VN', 'PH', 'MY', 'ID', 'KH', 'LA', 'MM', 'BN',
  // 欧洲
  'GB', 'FR', 'NL', 'IT', 'ES', 'CH', 'SE', 'NO', 'PL',
  'BE', 'AT', 'DK', 'FI', 'IE', 'PT', 'GR', 'CZ', 'RO',
  // 北美
  'CA', 'MX',
  // 南美
  'BR', 'AR', 'CL', 'CO',
  // 大洋洲
  'AU', 'NZ',
  // 中东
  'AE', 'SA', 'TR', 'IL',
  // 非洲
  'ZA', 'EG',
  // 亚洲其他
  'IN', 'PK'
];

const ZH = [
  '香港', '台湾', '澳门', '新加坡', '日本', '美国', '韩国', '德国', '俄罗斯',
  // 东南亚
  '泰国', '越南', '菲律宾', '马来西亚', '印度尼西亚', '柬埔寨', '老挝', '缅甸', '文莱',
  // 欧洲
  '英国', '法国', '荷兰', '意大利', '西班牙', '瑞士', '瑞典', '挪威', '波兰',
  '比利时', '奥地利', '丹麦', '芬兰', '爱尔兰', '葡萄牙', '希腊', '捷克', '罗马尼亚',
  // 北美
  '加拿大', '墨西哥',
  // 南美
  '巴西', '阿根廷', '智利', '哥伦比亚',
  // 大洋洲
  '澳大利亚', '新西兰',
  // 中东
  '阿联酋', '沙特', '土耳其', '以色列',
  // 非洲
  '南非', '埃及',
  // 亚洲其他
  '印度', '巴基斯坦'
];

const QC = [
  'Hong Kong', 'Taiwan', 'Macao', 'Singapore', 'Japan', 'United States', 'Korea', 'Germany', 'Russia',
  // 东南亚
  'Thailand', 'Vietnam', 'Philippines', 'Malaysia', 'Indonesia', 'Cambodia', 'Laos', 'Myanmar', 'Brunei',
  // 欧洲
  'United Kingdom', 'France', 'Netherlands', 'Italy', 'Spain', 'Switzerland', 'Sweden', 'Norway', 'Poland',
  'Belgium', 'Austria', 'Denmark', 'Finland', 'Ireland', 'Portugal', 'Greece', 'Czech', 'Romania',
  // 北美
  'Canada', 'Mexico',
  // 南美
  'Brazil', 'Argentina', 'Chile', 'Colombia',
  // 大洋洲
  'Australia', 'New Zealand',
  // 中东
  'UAE', 'Saudi Arabia', 'Turkey', 'Israel',
  // 非洲
  'South Africa', 'Egypt',
  // 亚洲其他
  'India', 'Pakistan'
];

const specialRegex = [
  /(\d\.)?\d+×/,
  /IPLC|IEPL|Kern|Edge|Pro|Std|Exp|Biz|Fam|Game|Buy|Zx|LB|Game/,
];

const nameclear =
  /(套餐|到期|有效|剩余|版本|已用|过期|失联|测试|官方|网址|备用|群|TEST|客服|网站|获取|订阅|流量|机场|下次|官址|联系|邮箱|工单|学术|USE|USED|TOTAL|EXPIRE|EMAIL)/i;

const regexArray=[
  /ˣ²/, /ˣ³/, /ˣ⁴/, /ˣ⁵/, /ˣ⁶/, /ˣ⁷/, /ˣ⁸/, /ˣ⁹/, /ˣ¹⁰/, /ˣ²⁰/, /ˣ³⁰/, /ˣ⁴⁰/, /ˣ⁵⁰/, 
  /IPLC/i, /IEPL/i, /核心/, /边缘/, /高级/, /标准/, /实验/, /商宽/, /家宽/, 
  /游戏|game/i, /购物/, /专线/, /LB/, /cloudflare/i, /\budp\b/i, /\bgpt\b/i, /udpn\b/
];

const valueArray= [
  "2×","3×","4×","5×","6×","7×","8×","9×","10×","20×","30×","40×","50×",
  "IPLC","IEPL","Kern","Edge","Pro","Std","Exp","Biz","Fam","Game","Buy","Zx","LB","CF","UDP","GPT","UDPN"
];

const nameblnx = /(高倍|(?!1)2+(x|倍)|ˣ²|ˣ³|ˣ⁴|ˣ⁵|ˣ¹⁰)/i;
const namenx = /(高倍|(?!1)(0\.|\d)+(x|倍)|ˣ²|ˣ³|ˣ⁴|ˣ⁵|ˣ¹⁰)/i;

const keya =
  /港|Hong|HK|新加坡|SG|Singapore|日本|Japan|JP|美国|United States|US|韩|土耳其|TR|Turkey|Korea|KR|泰|Thai|TH|越南|VN|Vietnam|菲律宾|PH|Philippines|马来|MY|Malaysia|英|UK|GB|Britain|法|FR|France|德|DE|Germany|🇸🇬|🇭🇰|🇯🇵|🇺🇸|🇰🇷|🇹🇷|🇹🇭|🇻🇳|🇵🇭|🇲🇾|🇬🇧|🇫🇷|🇩🇪/i;

const keyb =
  /(((1|2|3|4)\d)|(香港|Hong|HK) 0[5-9]|((新加坡|SG|Singapore|日本|Japan|JP|美国|United States|US|韩|土耳其|TR|Turkey|Korea|KR) 0[3-9]))/i;

// 扩展后的地区名称映射规则
const rurekey = {
  // 原有的
  "Russia Moscow": /Moscow|莫斯科/gi,
  "Korea Chuncheon": /Chuncheon|Seoul|首尔|春川/gi,
  "Hong Kong": /Hongkong|HONG KONG|HKG/gi,
  "Taiwan TW 台湾 🇹🇼": /(台|Tai\s?wan|TW).*?🇨🇳|🇨🇳.*?(台|Tai\s?wan|TW)/g,
  "United States": /USA|Los Angeles|San Jose|Silicon Valley|Michigan|洛杉矶|圣何塞|硅谷/gi,
  
  // 中文城市代码 - 原有
  德国: /(深|沪|呼|京|广|杭)德(?!.*(I|线))|法兰克福|滬德|Frankfurt/gi,
  香港: /(深|沪|呼|京|广|杭)港(?!.*(I|线))/g,
  日本: /(深|沪|呼|京|广|杭|中|辽)日(?!.*(I|线))|东京|大坂|Tokyo|Osaka/gi,
  新加坡: /狮城|(深|沪|呼|京|广|杭)新/gi,
  美国: /(深|沪|呼|京|广|杭)美|波特兰|芝加哥|哥伦布|纽约|硅谷|俄勒冈|西雅图/gi,
  台湾: /新台|新北|台(?!.*线)|Taipei|台北/gi,
  韩国: /春川|韩|首尔|Seoul/gi,
  俄罗斯: /莫斯科/gi,
  
  // 东南亚
  泰国: /泰|曼谷|Bangkok|(深|沪|呼|京|广|杭)泰/gi,
  "Thailand": /Thailand/gi,
  越南: /越南|胡志明|河内|Hanoi|Ho Chi Minh/gi,
  "Vietnam": /Vietnam/gi,
  菲律宾: /菲律宾|马尼拉|Manila/gi,
  "Philippines": /Philippines/gi,
  马来西亚: /马来|吉隆坡|Kuala Lumpur/gi,
  "Malaysia": /Malaysia/gi,
  印度尼西亚: /印尼|雅加达|Jakarta/gi,
  "Indonesia": /Indonesia/gi,
  
  // 欧洲
  英国: /英|伦敦|London|(深|沪|呼|京|广|杭)英/gi,
  "United Kingdom": /United Kingdom|Britain|UK(?!.*游戏)/gi,
  法国: /法|巴黎|Paris|(深|沪|呼|京|广|杭)法/gi,
  "France": /France/gi,
  荷兰: /荷兰|阿姆斯特丹|Amsterdam/gi,
  "Netherlands": /Netherlands/gi,
  意大利: /意大利|米兰|罗马|Milan|Rome/gi,
  "Italy": /Italy/gi,
  西班牙: /西班牙|马德里|巴塞罗那|Madrid|Barcelona/gi,
  "Spain": /Spain/gi,
  瑞士: /瑞士|苏黎世|Zurich/gi,
  "Switzerland": /Switzerland/gi,
  瑞典: /瑞典|斯德哥尔摩|Stockholm/gi,
  "Sweden": /Sweden/gi,
  挪威: /挪威|奥斯陆|Oslo/gi,
  "Norway": /Norway/gi,
  波兰: /波兰|华沙|Warsaw/gi,
  "Poland": /Poland/gi,
  
  // 北美
  加拿大: /加拿大|多伦多|温哥华|Toronto|Vancouver/gi,
  "Canada": /Canada/gi,
  
  // 南美
  巴西: /巴西|圣保罗|Sao Paulo/gi,
  "Brazil": /Brazil/gi,
  阿根廷: /阿根廷|布宜诺斯艾利斯|Buenos Aires/gi,
  "Argentina": /Argentina/gi,
  
  // 大洋洲
  澳大利亚: /澳|悉尼|墨尔本|Sydney|Melbourne/gi,
  "Australia": /Australia/gi,
  新西兰: /新西兰|奥克兰|Auckland/gi,
  "New Zealand": /New Zealand/gi,
  
  // 中东
  阿联酋: /阿联酋|迪拜|Dubai/gi,
  "UAE": /UAE|United Arab Emirates/gi,
  土耳其: /土耳其|伊斯坦布尔|Istanbul/gi,
  "Turkey": /Turkey/gi,
  以色列: /以色列|特拉维夫|Tel Aviv/gi,
  "Israel": /Israel/gi,
  
  // 亚洲其他
  印度: /印度|孟买|Mumbai/gi,
  "India": /India/gi,
  
  // 英文城市名映射
  "Taiwan": /Taipei/gi,
  "Japan": /Tokyo|Osaka/gi,
  "Germany": /Frankfurt/gi,
};

let GetK = false, AMK = []
function ObjKA(i) {
  GetK = true
  AMK = Object.entries(i)
}

function operator(pro) {
  const Allmap = {};
  const outList = getList(outputName);
  let inputList,
    retainKey = "";
  if (inname !== "") {
    inputList = [getList(inname)];
  } else {
    inputList = [ZH, FG, QC, EN];
  }

  inputList.forEach((arr) => {
    arr.forEach((value, valueIndex) => {
      Allmap[value] = outList[valueIndex];
    });
  });

  if (clear || nx || blnx || key) {
    pro = pro.filter((res) => {
      const resname = res.name;
      const shouldKeep =
        !(clear && nameclear.test(resname)) &&
        !(nx && namenx.test(resname)) &&
        !(blnx && !nameblnx.test(resname)) &&
        !(key && !(keya.test(resname) && /2|4|6|7/i.test(resname)));
      return shouldKeep;
    });
  }

  const BLKEYS = BLKEY ? BLKEY.split("+") : "";

  pro.forEach((e) => {
    let bktf = false, ens = e.name
    Object.keys(rurekey).forEach((ikey) => {
      if (rurekey[ikey].test(e.name)) {
        e.name = e.name.replace(rurekey[ikey], ikey);
      if (BLKEY) {
        bktf = true
        let BLKEY_REPLACE = "",
        re = false;
      BLKEYS.forEach((i) => {
        if (i.includes(">") && ens.includes(i.split(">")[0])) {
          if (rurekey[ikey].test(i.split(">")[0])) {
              e.name += " " + i.split(">")[0]
            }
          if (i.split(">")[1]) {
            BLKEY_REPLACE = i.split(">")[1];
            re = true;
          }
        } else {
          if (ens.includes(i)) {
             e.name += " " + i
            }
        }
        retainKey = re
        ? BLKEY_REPLACE
        : BLKEYS.filter((items) => e.name.includes(items));
      });}
      }
    });
    if (blockquic == "on") {
      e["block-quic"] = "on";
    } else if (blockquic == "off") {
      e["block-quic"] = "off";
    } else {
      delete e["block-quic"];
    }

    if (!bktf && BLKEY) {
      let BLKEY_REPLACE = "",
        re = false;
      BLKEYS.forEach((i) => {
        if (i.includes(">") && e.name.includes(i.split(">")[0])) {
          if (i.split(">")[1]) {
            BLKEY_REPLACE = i.split(">")[1];
            re = true;
          }
        }
      });
      retainKey = re
        ? BLKEY_REPLACE
        : BLKEYS.filter((items) => e.name.includes(items));
    }

    let ikey = "",
      ikeys = "";

    if (blgd) {
      regexArray.forEach((regex, index) => {
        if (regex.test(e.name)) {
          ikeys = valueArray[index];
        }
      });
    }

    if (bl) {
      const match = e.name.match(
        /((倍率|X|x|×)\D?((\d{1,3}\.)?\d+)\D?)|((\d{1,3}\.)?\d+)(倍|X|x|×)/
      );
      if (match) {
        const rev = match[0].match(/(\d[\d.]*)/)[0];
        if (rev !== "1") {
          const newValue = rev + "×";
          ikey = newValue;
        }
      }
    }

    !GetK && ObjKA(Allmap)
    const findKey = AMK.find(([key]) =>
      e.name.includes(key)
    )
    
    let firstName = "",
      nNames = "";

    if (nf) {
      firstName = FNAME;
    } else {
      nNames = FNAME;
    }
    if (findKey?.[1]) {
      const findKeyValue = findKey[1];
      let keyover = [],
        usflag = "";
      if (addflag) {
        const index = outList.indexOf(findKeyValue);
        if (index !== -1) {
          usflag = FG[index];
        }
      }
      keyover = keyover
        .concat(firstName, usflag, nNames, findKeyValue, retainKey, ikey, ikeys)
        .filter((k) => k !== "");
      e.name = keyover.join(FGF);
    } else {
      if (nm) {
        e.name = FNAME + FGF + e.name;
      } else {
        e.name = null;
      }
    }
  });
  pro = pro.filter((e) => e.name !== null);
  jxh(pro);
  numone && oneP(pro);
  blpx && (pro = fampx(pro));
  key && (pro = pro.filter((e) => !keyb.test(e.name)));
  return pro;
}

function getList(arg) { 
  switch (arg) { 
    case 'us': return EN; 
    case 'gq': return FG; 
    case 'quan': return QC; 
    default: return ZH; 
  }
}

function jxh(e) { 
  const n = e.reduce((e, n) => { 
    const t = e.find((e) => e.name === n.name); 
    if (t) { 
      t.count++; 
      t.items.push({ 
        ...n, 
        name: `${n.name}${XHFGF}${t.count.toString()}`, 
      }); 
    } else { 
      e.push({ 
        name: n.name, 
        count: 1, 
        items: [{ ...n, name: `${n.name}${XHFGF}1` }], 
      }); 
    } 
    return e; 
  }, []);
  const t=(typeof Array.prototype.flatMap==='function'?n.flatMap((e) => e.items):n.reduce((acc, e) => acc.concat(e.items),[])); 
  e.splice(0, e.length, ...t); 
  return e;
}

function oneP(e) { 
  const t = e.reduce((e, t) => { 
    const n = t.name.replace(/[^A-Za-z0-9\u00C0-\u017F\u4E00-\u9FFF]+\d+$/, ""); 
    if (!e[n]) { 
      e[n] = []; 
    } 
    e[n].push(t); 
    return e; 
  }, {}); 
  for (const e in t) { 
    if (t[e].length === 1 && t[e][0].name.endsWith("1")) { 
      t[e][0].name= t[e][0].name.replace(/[^.]1/, "") 
    } 
  } 
  return e; 
}

function fampx(pro) { 
  const wis = []; 
  const wnout = []; 
  for (const proxy of pro) { 
    const fan = specialRegex.some((regex) => regex.test(proxy.name)); 
    if (fan) { 
      wis.push(proxy); 
    } else { 
      wnout.push(proxy); 
    } 
  } 
  const sps = wis.map((proxy) => specialRegex.findIndex((regex) => regex.test(proxy.name)) ); 
  wis.sort( (a, b) => sps[wis.indexOf(a)] - sps[wis.indexOf(b)] || a.name.localeCompare(b.name) ); 
  wnout.sort((a, b) => pro.indexOf(a) - pro.indexOf(b)); 
  return wnout.concat(wis);
}
