let s = !1, o = 1e3, c = 3e3, a = {};
if ("undefined" != typeof $argument && "" !== $argument) {
    const n = l("$argument");
    s = 0 != n.hideIP, o = n.cnTimeout || 1e3, c = n.usTimeout || 3e3;
}
function l() {
    return Object.fromEntries($argument.split("&").map((e => e.split("="))).map((([e, t]) => [e, decodeURIComponent(t)])));
}
function r(e, t) {
    return e.length > t ? e.slice(0, t) : e.length < t ? e.toString().padEnd(t, " ") : e;
}
function p(e, t) {
    return e.split(" ", t).join(" ").replace(/\.|\,|com|\u4e2d\u56fd/g, "");
}
function u(e) {
    return e.replace(/(\w{1,4})(\.|\:)(\w{1,4}|\*)$/, ((e, t, n, i) => `${"∗".repeat(t.length)}.${"∗".repeat(i.length)}`));
}
function d(e) {
    const t = e.toUpperCase().split("").map((e => 127397 + e.charCodeAt()));
    return String.fromCodePoint(...t).replace(/🇹🇼/g, "🇨🇳");
}
async function g(e = "/v1/requests/recent", t = "GET", n = null) {
    return new Promise(((i, s) => {
        $httpAPI(t, e, n, (e => {
            i(e);
        }));
    }));
}
async function m(e, t) {
    let i = 1;
    const s = new Promise(((i, o) => {
        const c = async a => {
            try {
                const i = await Promise.race([new Promise(((t, n) => {
                    let i = Date.now();
                    $httpClient.get({ url: e }, ((e, s, o) => {
                        if (e) n(e);
                        else {
                            let e = Date.now() - i;
                            switch (s.status) {
                                case 200:
                                    let n = s.headers["Content-Type"];
                                    switch (!0) {
                                        case n.includes("application/json"):
                                            let i = JSON.parse(o);
                                            i.tk = e;
                                            t(i);
                                            break;
                                        case n.includes("text/html"):
                                            t("text/html");
                                            break;
                                        case n.includes("text/plain"):
                                            let s = o.split("\n").reduce(((t, n) => {
                                                let [i, s] = n.split("=");
                                                return t[i] = s, t[i] = s, t.tk = e, t;
                                            }), {});
                                            t(s);
                                            break;
                                        case n.includes("image"):
                                            t("image");
                                            break;
                                        default:
                                            t("未知");
                                    }
                                    break;
                                case 204:
                                    t({ tk: e });
                                    break;
                                case 429:
                                    console.log("次数过多");
                                    t("429");
                                    break;
                                case 404:
                                    t("404");
                                    break;
                                default:
                                    t("nokey");
                                }
                        }
                    })), new Promise(((t, n) => {
                    setTimeout((() => n(new Error("timeout"))), t);
                }))]));
                i ? s(i) : (s("超时"), o(new Error(n.message)));
            } catch (e) {
                a < 1 ? (i++, c(a + 1)) : (s("检测失败, 重试次数" + i), o(e));
            }
        };
        c(0);
    }));
    return s;
}
(async () => {
    let n = "", l = "节点信息查询", p = "", f = "";
    const P = await m("http://ip-api.com/json/?lang=zh-CN", c);
    if ("success" === P.status) {
        console.log("ipapi" + JSON.stringify(P, null, 2));
        let { country: e, countryCode: t, regionName: i, query: o, city: c, isp: l } = P;
        n = o;
        e === c && (c = "");
        p = `落地地区: ${d(t)} ${e} ${c}\n落地 IP: ${o}\n落地运营商: ${l}`;
    } else {
        console.log("ild" + JSON.stringify(P));
        p = "落地地区: 查询失败\n落地 IP: 无\n落地运营商: 无";
    }
    let h, w = "";
    let k = (await g()).requests.slice(0, 6).filter((e => /ip-api\.com/.test(e.URL)));
    if (k.length > 0) {
        const e = k[0];
        /\(Proxy\)/.test(e.remoteAddress) ? (h = e.remoteAddress.replace(" (Proxy)", "")) : (h = "Noip", w = "直连节点:");
    } else {
        h = "Noip";
    }
    let N = !1, $ = !1, isv6 = !1, cn = !0;
    if ("Noip" === h) {
        N = !0;
    } else if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(h)) {
        $ = !0;
    } else if (/^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$/.test(h)) {
        isv6 = !0;
    }
    if (h == n) {
        cn = !1;
        w = "直连节点:";
    } else {
        if ("" === w) w = "入口地区:";
        if (!N || $) {
            const e = await m(`https://api-v3.speedtest.cn/ip?ip=${h}`, o);
            if (0 === e.code && "中国" === e.data.country) {
                let { province: t, isp: n, city: i, countryCode: o } = e.data;
                console.log("ik" + JSON.stringify(e, null, 2));
                cn = !0;
                f = `入口地区: ${d(o)} ${t} ${i}\n入口 IP: ${h}\n入口运营商: ${n}\n`;
            } else {
                cn = !1;
                console.log("ik" + JSON.stringify(e));
                f = "入口地区: 查询失败\n入口 IP: 无\n入口运营商: 无\n";
            }
        }
        if ((!N || isv6) && !cn) {
            const e = await m(`http://ip-api.com/json/${h}?lang=zh-CN`, c);
            if ("success" === e.status) {
                console.log("iai" + JSON.stringify(e, null, 2));
                let { countryCode: t, country: n, city: i, isp: c } = e;
                f = `入口地区: ${d(t)} ${n} ${i}\n入口 IP: ${h}\n入口运营商: ${c}\n`;
            } else {
                console.log("iai" + JSON.stringify(e));
                f = "入口地区: 查询失败\n入口 IP: 无\n入口运营商: 无\n";
            }
        }
    }
    a = { title: l, content: f + p };
})().catch((e => console.log(e.message))).finally((() => $done(a)));
