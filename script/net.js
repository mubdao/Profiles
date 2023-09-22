// 作者：@keywos
let pro = {
    icons: 'globe.asia.australia',
    icolor: '#6699FF',
    GPT: false,
    hideIP: false,
    nw: true,
    说明: '可在持久化数据中更改是否在面板中显示这样可以直接使用远程链接，不用放在本地即可修改，输错了会自动恢复默认重新运行后重写JSON里的参数即可',
    'icons 为图标': 'icolor 为颜色',
    'hideIP 为': '是否隐藏IP',
    开为: true,
    关为: false,
    version: 20230921.1
  },
  data;
(async () => {
  try {
    try {
      let e = $persistentStore.read('KeyNetisp');
      data = e ? JSON.parse(e) : pro;
      if (
        data.nw ||
        data.version !== pro.version ||
        typeof data.hideIP !== 'boolean' ||
        typeof data.GPT !== 'boolean' ||
        typeof data.icons !== 'string' ||
        typeof data.icolor !== 'string'
      ) {
        console.log('无数据或数据错误,恢复默认');
        delete pro.nw;
        $persistentStore.write(JSON.stringify(pro, '', 2), 'KeyNetisp');
        data = pro;
      }
    } catch (e) {
      data = pro;
    }
    let e = data.GPT,
      t = data.icons,
      s = data.icolor,
      o = data.hideIP;
    let n = '',
      a = '',
      i = '节点信息查询',
      l = '\n---------------------\n代理链',
      r = '',
      c = '',
      p = '',
      d = '';
    const u = await tKey('http://ip-api.com/json/?lang=zh-CN', 1200);
    if (u.status === 'success') {
      let { country: e, countryCode: t, regionName: s, query: a, city: i, org: l, isp: c, as: p, tk: d } = u;
      n = a;
      o && (a = a.slice(0, 6) + '∗∗∗∗∗');
      e === i && (i = '');
      let f = getflag(t) + e + ' ' + i;
      r = f + '\n落地IP: \t' + a + ': ' + d + 'ms' + '\n落地ISP: \t' + c + '\n落地ASN: \t' + p + '';
    } else {
      console.log('ild' + u);
      r = '';
    }
    if (e) {
      const e = await tKey('http://chat.openai.com/cdn-cgi/trace', 1e3);
      const t = ['CN', 'TW', 'HK', 'IR', 'KP', 'RU', 'VE', 'BY'];
      if (typeof e !== 'string') {
        let { loc: s, tk: o, warp: n, ip: a } = e,
          l = t.indexOf(s),
          r = '';
        if (l == -1) {
          r = 'GPT: ' + s + ' ✓';
        } else {
          r = 'GPT: ' + s + ' ×';
        }
        if ((n = 'plus')) {
          n = 'Plus';
        }
        i = r + '       ➟     Priv: ' + n + '   ' + o + 'ms';
      } else {
        i = 'ChatGPT ' + e;
      }
    }
    const f = await httpAPI();
    let g;
    const y = f.requests.slice(0, 6);
    let m = y.filter(e => /ip-api\.com/.test(e.URL));
    if (m.length > 0) {
      const e = m[0];
      d = e.policyName;
      if (/\(Proxy\)/.test(e.remoteAddress)) {
        g = e.remoteAddress.replace(' (Proxy)', '');
        l = '';
      } else {
        g = e.remoteAddress;
      }
    } else {
      g = 'Noip';
    }
    let P = false,
      h = 'spe',
      w = false,
      k = 'edtest';
    (isv6 = false), (cn = true), (zl = '');
    if (g === 'Noip') {
      P = true;
    } else if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(g)) {
      w = true;
    } else if (/^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/.test(g)) {
      isv6 = true;
    }
    if (g == n) {
      cn = false;
      zl = '直连节点:';
    } else {
      zl = '';
      if (!P || w) {
        const e = await tKey(`https://api-v3.${h}${k}.cn/ip?ip=${g}`, 500);
        if (e.code === 0 && e.data.country === '中国') {
          let { province: t, isp: s, city: n, countryCode: a } = e.data,
            i = e.tk;
          cn = true;
          o && (g = g.slice(0, 6) + '∗∗∗∗∗');
          c =
            getflag(a) +
            t +
            ' ' +
            n +
            '\n入口IP: \t' +
            g +
            ': ' +
            i +
            'ms' +
            '\n入口ISP: \t' +
            s +
            l +
            '\n---------------------\n';
        } else {
          cn = false;
          console.log(e);
          c = '入口IPA Failed\n';
        }
      }
      if ((!P || isv6) && !cn) {
        const e = await tKey(`http://ip-api.com/json/${g}?lang=zh-CN`, 1e3);
        if (e.status === 'success') {
          let { countryCode: t, country: s, city: n, tk: a, isp: i } = e;
          o && (g = g.slice(0, 6) + '∗∗∗∗∗');
          let r = s + ' ' + n;
          c =
            getflag(t) +
            r +
            '\n入口IP: \t' +
            g +
            ': ' +
            a +
            'ms' +
            '\n入口ISP: \t' +
            i +
            l +
            '\n---------------------\n';
        } else {
          console.log(e);
          c = '入口IPB Failed\n';
        }
      }
    }
    $done({
      title: d,
      content: p + a + c + zl + r,
      icon: t,
      'icon-color': s
    });
  } catch (e) {
    console.log(e.message);
    $done({
      title: outgpt + nodeNames,
      content: local + outbli + outik + outld + zl,
      icon: icons,
      'icon-color': icolor
    });
  }
})(),
  function e(t, s) {
    if (t.length > s) {
      return t.slice(0, s);
    } else if (t.length < s) {
      return t.toString().padEnd(s, ' ');
    } else {
      return t;
    }
  };

function sK(e, t) {
  return e
    .split(' ', t)
    .join(' ')
    .replace(/\.|\,|com|\u4e2d\u56fd/g, '');
}
async function httpAPI(e = '/v1/requests/recent', t = 'GET', s = null) {
  return new Promise((o, n) => {
    $httpAPI(t, e, s, e => {
      o(e);
    });
  });
}

function getflag(e) {
  const t = e
    .toUpperCase()
    .split('')
    .map(e => 127397 + e.charCodeAt());
  return String.fromCodePoint(...t).replace(/🇹🇼/g, '🇨🇳');
}
async function tKey(e, t) {
  let s = 1,
    o = 1;
  const a = new Promise((a, i) => {
    const l = async r => {
      try {
        const s = await Promise.race([
          new Promise((t, s) => {
            let o = Date.now();
            $httpClient.get(
              {
                url: e
              },
              (e, n, a) => {
                if (e) {
                  s(e);
                } else {
                  let e = Date.now() - o;
                  let s = n.status;
                  switch (s) {
                    case 200:
                      let s = n.headers['Content-Type'];
                      switch (true) {
                        case s.includes('application/json'):
                          let o = JSON.parse(a);
                          o.tk = e;
                          t(o);
                          break;
                        case s.includes('text/html'):
                          t('text/html');
                          break;
                        case s.includes('text/plain'):
                          let n = a.split('\n');
                          let i = n.reduce((t, s) => {
                            let [o, n] = s.split('=');
                            t[o] = n;
                            t.tk = e;
                            return t;
                          }, {});
                          t(i);
                          break;
                        case s.includes('image/svg+xml'):
                          t('image/svg+xml');
                          break;
                        default:
                          t('未知');
                          break;
                      }
                      break;
                    case 204:
                      let o = {
                        tk: e
                      };
                      t(o);
                      break;
                    case 429:
                      console.log('次数过多');
                      t('次数过多');
                      break;
                    case 404:
                      console.log('404');
                      t('404');
                      break;
                    default:
                      t('nokey');
                      break;
                  }
                }
              }
            );
          }),
          new Promise((e, s) => {
            setTimeout(() => s(new Error('timeout')), t);
          })
        ]);
        if (s) {
          a(s);
        } else {
          a('超时');
          i(new Error(n.message));
        }
      } catch (e) {
        if (r < s) {
          o++;
          l(r + 1);
        } else {
          a('检测失败, 重试次数' + o);
          i(e);
        }
      }
    };
    l(0);
  });
  return a;
}
