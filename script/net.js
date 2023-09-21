let pro = {
    icons: "globe.asia.australia",
    icolor: "#6699FF",
    GPT: false,
    nw: true,
    "说明": "可在持久化数据中更改是否在面板中显示这样可以直接使用远程链接，不用放在本地即可修改，输错了会自动恢复默认重新运行后重写JSON里的参数即可",
    "icons 为图标": "icolor 为颜色",
    "开为": true,
    "关为": false,
    version: 20230920
  },
  data;
(async () => {
  try {
    try {
      let e = $persistentStore.read("KeyNetisp");
      data = e ? JSON.parse(e) : pro;
      if(data.nw || data.version !== pro.version || typeof data.GPT !==
        "boolean" || typeof data.icons !== "string" || typeof data
        .icolor !== "string") {
        console.log("无数据或数据错误,恢复默认");
        delete pro.nw;
        $persistentStore.write(JSON.stringify(pro, "", 2),
          "KeyNetisp");
        data = pro
      }
    } catch (e) {
      data = pro
    }
    let e = data.GPT,
      t = data.icons,
      s = data.icolor;
    let o = "",
      n = "",
      a = "节点信息查询",
      i = "\n---------------------\n代理链",
      l = "",
      r = "",
      c = "",
      p = "";
    const u = await tKey("http://ip-api.com/json/?lang=zh-CN", 1200);
    if(u.status === "success") {
      let {
        country: e,
        countryCode: t,
        regionName: s,
        query: n,
        city: a,
        org: i,
        isp: r,
        as: c,
        tk: p
      } = u;
      o = n;
      e === a && (a = "");
      let d = getflag(t) + e + " " + a;
      l = " \t" + sMN(d) + "\n落地IP: \t" + n + ": " + p + "ms" +
        "\n落地ISP: \t" + sMN(r) + "\n落地ASN: \t" + sMN(c) + ""
    } else {
      console.log("ild" + u);
      l = ""
    }
    if(e) {
      const e = await tKey("http://chat.openai.com/cdn-cgi/trace",
        1e3);
      const t = ["CN", "TW", "HK", "IR", "KP", "RU", "VE", "BY"];
      if(typeof e !== "string") {
        let {
          loc: s,
          tk: o,
          warp: n,
          ip: i
        } = e, l = t.indexOf(s), r = "";
        if(l == -1) {
          r = "GPT: " + s + " ✓"
        } else {
          r = "GPT: " + s + " ×"
        }
        if(n = "plus") {
          n = "Plus"
        }
        a = r + "       ➟     Priv: " + n + "   " + o + "ms"
      } else {
        a = "ChatGPT " + e
      }
    }
    const d = await httpAPI();
    let f;
    const g = d.requests.slice(0, 6);
    let y = g.filter((e => /ip-api\.com/.test(e.URL)));
    if(y.length > 0) {
      const e = y[0];
      p = ": " + e.policyName;
      if(/\(Proxy\)/.test(e.remoteAddress)) {
        f = e.remoteAddress.replace(" (Proxy)", "");
        i = ""
      } else {
        f = e.remoteAddress
      }
    } else {
      f = "Noip"
    }
    let m = false,
      P = "spe",
      h = false,
      w = "edtest";
    isv6 = false, cn = true, zl = "";
    if(f === "Noip") {
      m = true
    } else if(/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(f)) {
      h = true
    } else if(/^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/.test(f)) {
      isv6 = true
    }
    if(f == o) {
      cn = false;
      zl = "直连节点:"
    } else {
      zl = "落地地区:";
      if(!m || h) {
        const e = await tKey(
          `https://api-v3.${P}${w}.cn/ip?ip=${f}`, 500);
        if(e.code === 0 && e.data.country === "中国") {
          let {
            province: t,
            isp: s,
            city: o,
            countryCode: n
          } = e.data, a = e.tk;
          cn = true;
          r = "入口国家: \t" + getflag(n) + t + " " + o +
            "\n入口IP: \t" + f + ": " + a + "ms" +
            "\n入口ISP: \t" + s + i +
            "\n---------------------\n"
        } else {
          cn = false;
          console.log(e);
          r = "入口IPA Failed\n"
        }
      }
      if((!m || isv6) && !cn) {
        const e = await tKey(
          `http://ip-api.com/json/${f}?lang=zh-CN`, 1e3);
        if(e.status === "success") {
          let {
            countryCode: t,
            country: s,
            city: o,
            org: n,
            tk: a,
            isp: l
          } = e;
          let c = s + " " + o;
          r = "入口国家: \t" + getflag(t) + sMN(c) + "\n入口IP: \t" +
            f + ": " + a + "ms" + "\n入口ISP: \t" + sMN(l) +
            i + "\n---------------------\n"
        } else {
          console.log(e);
          r = "入口IPB Failed\n"
        }
      }
    }
    $done({
      title: a + p,
      content: c + n + r + zl + l,
      icon: t,
      "icon-color": s
    })
  } catch (e) {
    console.log(e.message);
    $done({
      title: outgpt + nodeNames,
      content: local + outbli + outik + outld + zl,
      icon: icons,
      "icon-color": icolor
    })
  }
})(),
function e(t, s) {
  if(t.length > s) {
    return t.slice(0, s)
  } else if(t.length < s) {
    return t.toString()
      .padEnd(s, " ")
  } else {
    return t
  }
};

function sK(e, t) {
  return e.split(" ", t)
    .join(" ")
    .replace(/\.|\,|com|\u4e2d\u56fd/g, "")
}
async function httpAPI(e = "/v1/requests/recent", t = "GET", s = null) {
  return new Promise(((o, n) => {
    $httpAPI(t, e, s, (e => {
      o(e)
    }))
  }))
}

function sMN(e) {
  return e
}

function getflag(e) {
  const t = e.toUpperCase()
    .split("")
    .map((e => 127397 + e.charCodeAt()));
  return String.fromCodePoint(...t)
    .replace(/🇹🇼/g, "🇨🇳")
}
async function tKey(e, t) {
    let s = 1,
      o = 1;
    const a = new Promise(((a, i) => {
            const l = async r => {
                  try {
                    const s = await Promise.race([new Promise(
                            ((t, s) => {
                                let o = Date.now();
                                $httpClient.get({
                                      url: e
                                    }, ((e,
                                        n,
                                        a
                                      ) => {
                                        if(
                                          e
                                        ) {
                                          s
                                            (
                                              e
                                            )
                                        } else {
                                          let
                                            e =
                                            Date
                                            .now() -
                                            o;
                                          let
                                            s =
                                            n
                                            .status;
                                          switch (
                                            s
                                          ) {
                                            case 200:
                                              let
                                                s =
                                                n
                                                .headers[
                                                  "Content-Type"
                                                ];
                                              switch (
                                                true
                                              ) {
                                                case s
                                                .includes(
                                                  "application/json"
                                                ):
                                                  let
                                                    o =
                                                    JSON
                                                    .parse(
                                                      a
                                                    );
                                                  o
                                                    .tk =
                                                    e;
                                                  t
                                                    (
                                                      o
                                                    );
                                                  break;
                                                case s
                                                .includes(
                                                  "text/html"
                                                ):
                                                  t
                                                    (
                                                      "text/html"
                                                    );
                                                  break;
                                                case s
                                                .includes(
                                                  "text/plain"
                                                ):
                                                  let
                                                    n =
                                                    a
                                                    .split(
                                                      "\n"
                                                    );
                                                  let
                                                    i =
                                                    n
                                                    .reduce(
                                                      (
                                                        (
                                                          t,
                                                          s
                                                        ) => {
                                                          let [
                                                            o,
                                                            n
                                                          ] =
                                                          s
                                                            .split(
                                                              "="
                                                            );
                                                          t
                                                            [
                                                              o
                                                            ] =
                                                            n;
                                                          t
                                                            .tk =
                                                            e;
                                                          return t
                                                        }
                                                      ), {}
                                                    );
                                                  t
                                                    (
                                                      i
                                                    );
                                                  break;
                                                case s
                                                .includes(
                                                  "image/svg+xml"
                                                ):
                                                  t
                                                    (
                                                      "image/svg+xml"
                                                    );
                                                  break;
                                                default:
                                                  t
                                                    (
                                                      "未知"
                                                    );
                                                  break
                                              }
                                              break;
                                            case 204:
                                              let
                                                o = {
                                                  tk: e
                                                };
                                              t
                                                (
                                                  o
                                                );
                                              break;
                                            case 429:
                                              console
                                                .log(
                                                  "次数过多"
                                                );
                                              t
                                                (
                                                  "次数过多"
                                                );
                                              break;
                                            case 404:
                                              console
                                                .log(
                                                  "404"
                                                );
                                              t
                                                (
                                                  "404"
                                                )
