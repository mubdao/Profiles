let i = !1, o = 1e3, c = 3e3, a = {};
if ("undefined" != typeof $argument && "" !== $argument) {
    const n = l($argument);
    i = "1" === n.gpt || "true" === n.gpt, 
    o = n.cntimeout ? parseInt(n.cntimeout) : 1e3, 
    c = n.ustimeout ? parseInt(n.ustimeout) : 3e3;
}

function l(e) {
    const params = {};
    if (!e) return params;
    e.split("&").forEach(item => {
        const [key, value] = item.split("=");
        if (key) params[key.toLowerCase()] = decodeURIComponent(value || "");
    });
    return params;
}

function d(e) {
    const t = e.toUpperCase().split("").map(char => 127397 + char.charCodeAt());
    return String.fromCodePoint(...t).replace(/🇹🇼/g, "🇨🇳");
}

async function m(e, t) {
    return new Promise((resolve, reject) => {
        let retries = 0;
        const attempt = () => {
            const start = Date.now();
            $httpClient.get({ url: e }, (error, response, body) => {
                if (error) {
                    if (retries < 1) {
                        retries++;
                        setTimeout(attempt, 500);
                    } else {
                        reject(`请求失败: ${error}`);
                    }
                    return;
                }
                const latency = Date.now() - start;
                let result = { tk: latency };
                if (response.status === 200) {
                    const ct = response.headers["Content-Type"] || "";
                    if (ct.includes("application/json")) {
                        try {
                            result = { ...JSON.parse(body), tk: latency };
                        } catch (e) {
                            result = "JSON解析错误";
                        }
                    } else if (ct.includes("text/plain")) {
                        const lines = body.split("\n");
                        lines.forEach(line => {
                            const [key, value] = line.split("=");
                            if (key && value) result[key] = value;
                        });
                        result.tk = latency;
                    } else {
                        result = body || "未知响应";
                    }
                } else if (response.status === 204) {
                    result = { tk: latency };
                } else {
                    result = `HTTP ${response.status}`;
                }
                resolve(result);
            });
        };
        const timeout = setTimeout(() => {
            reject("超时");
        }, t);
        attempt();
    });
}

async function g(e = "/v1/requests/recent", t = "GET", n = null) {
    return new Promise((resolve) => {
        $httpAPI(t, e, n, resolve);
    });
}

(async() => {
    let n = "", l = "", p = "", f = "";
    try {
        const P = await m("http://ip-api.com/json/?lang=zh-CN", c);
        if (P.status === "success") {
            const { country, countryCode, regionName, city, query, isp } = P;
            n = query;
            const region = `${d(countryCode)} ${regionName || country}${city && city !== (regionName || country) ? " " + city : ""}`;
            p = `落地：${region}  ${query}\n运营：${isp}`;
        }
    } catch (e) {
        p = "落地信息获取失败";
    }
    if (i) {
        try {
            const trace = await m("http://chat.openai.com/cdn-cgi/trace", c);
            if (typeof trace === "object" && trace.loc) {
                const blocked = ["CN", "TW", "HK", "IR", "KP", "RU", "VE", "BY"].includes(trace.loc);
                l = `GPT: ${trace.loc} ${blocked ? "×" : "✓"}`;
            } else if (typeof trace === "string") {
                l = `GPT检测失败: ${trace}`;
            }
        } catch (e) {
            l = "GPT检测失败";
        }
    }
    let entryIP = "";
    try {
        const requests = (await g()).requests;
        const recent = requests.slice(0, 6).find(r => /ip-api\.com/.test(r.URL));
        if (recent) {
            entryIP = recent.remoteAddress.replace(" (Proxy)", "");
            if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(entryIP)) {
                try {
                    const cnResponse = await m(`https://api-v3.speedtest.cn/ip?ip=${entryIP}`, o);
                    if (cnResponse.code === 0 && cnResponse.data.country === "中国") {
                        const { province, city, isp, countryCode } = cnResponse.data;
                        const region = `${d(countryCode)} ${province}${city && city !== province ? " " + city : ""}`;
                        f = `入口：${region}  ${entryIP}\n运营：${isp}`;
                    }
                } catch (e) {}
            }
            if (!f && entryIP !== n) {
                try {
                    const intlResponse = await m(`http://ip-api.com/json/${entryIP}?lang=zh-CN`, c);
                    if (intlResponse.status === "success") {
                        const { country, countryCode, city, isp } = intlResponse;
                        const region = `${d(countryCode)} ${country}${city && city !== country ? " " + city : ""}`;
                        f = `入口：${region}  ${entryIP}\n运营：${isp}`;
                    }
                } catch (e) {}
            }
        }
    } catch (e) {
        f = "入口信息获取失败";
    }
    if (entryIP === n && p) {
        f = "入口：直连";
    }
    const content = [];
    if (f) content.push(f);
    if (p) content.push(p);
    a = {
        title: l || "节点信息",
        content: content.join("\n\n")
    };
})().catch(e => {
    a = {
        title: "脚本错误",
        content: e.message || String(e)
    };
}).finally(() => $done(a));
