const inArg = $arguments;
const numone = inArg.one || false,
      addflag = inArg.flag || false,
      nm = inArg.nm || false,
      BLKEY = inArg.blkey == undefined ? "" : decodeURI(inArg.blkey),
      nameMap = {
        zh: "zh",
        en: "en",
        quan: "quan",
        flag: "flag",
      },
      inname = nameMap[inArg.in] || "",
      outputName = nameMap[inArg.out] || "";

const FG = ['🇨🇳', '🇭🇰', '🇲🇴', '🇨🇳', '🇯🇵', '🇰🇷', '🇺🇸', '🇬🇧', '🇩🇪', '🇫🇷', '🇷🇺', '🇹🇷', '🇸🇬'];
const EN = ['CN', 'HK', 'MO', 'TW', 'JP', 'KR', 'US', 'GB', 'DE', 'FR', 'RU', 'TR', 'SG'];
const ZH = ['中国', '香港', '澳门', '台湾', '日本', '韩国', '美国', '英国', '德国', '法国', '俄罗斯', '土耳其', '新加坡'];
const QC = ['China', 'Hong Kong', 'Macao', 'Taiwan', 'Japan', 'Korea', 'United States', 'United Kingdom', 'Germany', 'France', 'Russia', 'Turkey', 'Singapore'];

const rurekey = {
  中国: /(深|沪|呼|京|广|杭)中/g,
  香港: /(Hongkong|HONG KONG|(深|沪|呼|京|广|杭)港(?!.*(I|线)))/g,
  澳门: /Macao/g,
  台湾: /(新台|新北|台(?!.*线)|Tai\s?wan|Taipei)/g,
  日本: /((深|沪|呼|京|广|杭|中|辽)日(?!.*(I|线))|Tokyo|Osaka|大坂|东京)/g,
  韩国: /(春川|韩|首尔|Korea|Seoul|Chuncheon)/g,
  美国: /((深|沪|呼|京|广|杭)美|USA|Los Angeles|San Jose|Silicon Valley|Michigan|波特兰|芝加哥|哥伦布|纽约|硅谷|俄勒冈|西雅图)/g,
  英国: /(UK|London|Great Britain|伦敦)/g,
  德国: /((深|沪|呼|京|广|杭)德(?!.*(I|线))|Frankfurt|法兰克福|滬德)/g,
  法国: /(巴黎|Paris)/g,
  俄罗斯: /(莫斯科|Moscow|Russia)/g,
  土耳其: /(伊斯坦布尔|Turkey|Istanbul)/g,
  新加坡: /(Singapore|狮城|新(?!.*(加坡I|线|西兰)))/g,
};

let GetK = false, AMK = [];
function ObjKA(i) {
  GetK = true;
  AMK = Object.entries(i);
}

function operator(pro) {
  const Allmap = {};
  const outList = getList(outputName);
  let inputList;
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

  const BLKEYS = BLKEY ? BLKEY.split("+") : [];

  pro.forEach((e) => {
    let bktf = false, ens = e.name;

    let retainKeys = [];
    if (BLKEY) {
      BLKEYS.forEach((i) => {
        if (i.includes(">")) {
          const [src, dst] = i.split(">");
          if (e.name.includes(src)) {
            e.name = e.name.replace(src, dst || src);
            retainKeys.push(dst || src);
            bktf = true;
          }
        } else {
          if (e.name.includes(i)) {
            retainKeys.push(i);
            bktf = true;
          }
        }
      });
    }

    Object.keys(rurekey).forEach((ikey) => {
      if (rurekey[ikey].test(e.name)) {
        e.name = e.name.replace(rurekey[ikey], ikey);
        bktf = true;
      }
    });

    !GetK && ObjKA(Allmap);
    const findKey = AMK.find(([key]) => e.name.includes(key));
    let retainKey = retainKeys.join(" ");

    if (findKey?.[1]) {
      const findKeyValue = findKey[1];
      let keyover = [], usflag = "";
      if (addflag) {
        const index = outList.indexOf(findKeyValue);
        if (index !== -1) {
          usflag = FG[index];
          usflag = usflag === "🇨🇳" && findKeyValue === "台湾" ? "🇨🇳" : usflag;
        }
      }
      keyover = keyover.concat(usflag, findKeyValue, retainKey).filter((k) => k !== "");
      e.name = keyover.join(" ");
    } else {
      if (nm && bktf) {
        e.name = retainKey ? retainKey : e.name;
      } else if (nm) {
        e.name = e.name;
      } else {
        e.name = null;
      }
    }
  });

  pro = pro.filter((e) => e.name !== null);
  jxh(pro);
  numone && oneP(pro);
  return pro;
}

function getList(arg) {
  switch (arg) {
    case 'en': return EN;
    case 'flag': return FG;
    case 'quan': return QC;
    default: return ZH;
  }
}

function jxh(e) {
  const n = e.reduce((e, n) => {
    const t = e.find((e) => e.name === n.name);
    if (t) {
      t.count++;
      t.items.push({ ...n, name: `${n.name} ${t.count.toString().padStart(2, "0")}` });
    } else {
      e.push({ name: n.name, count: 1, items: [{ ...n, name: `${n.name} 01` }] });
    }
    return e;
  }, []);
  const t = (typeof Array.prototype.flatMap === 'function' ? n.flatMap((e) => e.items) : n.reduce((acc, e) => acc.concat(e.items), []));
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
    if (t[e].length === 1 && t[e][0].name.endsWith("01")) {
      t[e][0].name = t[e][0].name.replace(/[^.]01/, "");
    }
  }
  return e;
}