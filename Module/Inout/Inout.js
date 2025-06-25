let e = "globe.asia.australia", t = "#6699FF", i = !1, o = 1e3, c = 3e3, a = {};

if ("undefined" != typeof $argument && "" !== $argument) {
    const n = l("$argument");
    e = n.icon || e;
    t = n.icolor || t;
    i = 0 != n.GPT;
    o = n.cnTimeout || 1e3;
    c = n.usTimeout || 3e3;
}

function l() {
    return Object.fromEntries($argument.split("&").map((e => e.split("="))).map((([e, t]) => [e, decodeURIComponent(t)])))
}

function d(e) {
    const t = e.toUpperCase().split("").map((e => 127397 + e.charCodeAt()));
    return String.fromCodePoint(...t).replace(/🇹🇼/g, "🇨🇳")
}

async function g(e = "/v1/requests/recent", t = "GET", n = null) {
    return new Promise(((i, s) => {
        $httpAPI(t, e, n, (e => {
            i(e)
        }))
    }))
}

async function m(e, t) {
    let i = 1;
    const s = new Promise(((s, o) => {
        const c = async a => {
            try {
                const i = await Promise.race([
                    new Promise(((t, n) => {
                        $httpClient.get({ url: e }, ((e, s, o) => {
                            if (e) n(e);
                            else {
                                let n = s.status;
                                if (n === 200) {
                                    let type = s.headers["Content-Type"];
                                    if (type.includes("application/json")) {
                                        let json = JSON.parse(o);
                                        t(json);
                                    } else if (type.includes("text/plain")) {
                                        let result = o.split("\n").reduce(((obj, line) => {
                                            let [k, v] = line.split("=");
                                            obj[k] = v;
                                            return obj;
                                        }), {});
                                        t(result);
                                    } else {
                                        t("未知");
                                    }
                                } else if (n === 204) {
                                    t({});
                                } else {
                                    t("nokey");
                                }
                            }
                        }))
                    })),
                    new Promise(((e, n) => {
                        setTimeout((() => n(new Error("timeout"))), t)
                    }))
                ]);
                i ? s(i) : o(new Error("失败"))
            } catch (e) {
                a < 1 ? (i++, c(a + 1)) : o(e)
            }
        };
        c(0)
    }));
    return s;
}

(async () => {
    let title = "节点信息";
    let entryText = "", exitText = "", chatGPTText = "", ipCompareLabel = "", fullText = "";

    // 获取落地 IP 信息
    const P = await m("http://ip-api.com/json/?lang=zh-CN", c);
    if ("success" === P.status) {
        let { country, countryCode, city, query, isp } = P;
        if (country === city) city = "";
        exitText = `落地国家:\t${d(countryCode)}${country} ${city}\n落地IP:\t${query}\n落地ISP:\t${isp}\n`;
    }

    // ChatGPT 可用性检测
    if (i) {
        const gpt = await m("http://chat.openai.com/cdn-cgi/trace", c);
        const blockList = ["CN", "TW", "HK", "IR", "KP", "RU", "VE", "BY"];
        if (typeof gpt !== "string") {
            let { loc, warp } = gpt;
            chatGPTText = blockList.includes(loc) ? `GPT:\t${loc} ×` : `GPT:\t${loc} ✓`;
        } else {
            chatGPTText = `ChatGPT 状态异常`;
        }
        title += " | " + chatGPTText;
    }

    // 获取入口 IP（代理链）
    let h, k = (await g()).requests.slice(0, 6).filter((e => /ip-api\.com/.test(e.URL)));
    if (k.length > 0) {
        const e = k[0];
        if (/\(Proxy\)/.test(e.remoteAddress)) {
            h = e.remoteAddress.replace(" (Proxy)", "");
            ipCompareLabel = "入口国家:";
        } else {
            h = "Noip";
        }
    } else {
        h = "Noip";
    }

    // 获取入口 IP 的信息
    if ("Noip" !== h && /^\d{1,3}(\.\d{1,3}){3}$/.test(h)) {
        const ipData = await m(`http://ip-api.com/json/${h}?lang=zh-CN`, c);
        if (ipData.status === "success") {
            let { country, countryCode, city, isp } = ipData;
            entryText = `入口国家:\t${d(countryCode)}${country} ${city}\n入口IP:\t${h}\n入口ISP:\t${isp}\n`;
        } else {
            entryText = "入口信息获取失败\n";
        }
    }

    fullText = `${entryText}\n${exitText}`;
    a = {
        title: title,
        content: fullText.trim()
    };
})().catch((e => console.log(e.message))).finally((() => $done(a)));
