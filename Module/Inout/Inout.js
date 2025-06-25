let i = false, o = 1e3, c = 3e3, a = {};

if ("undefined" !== typeof $argument && $argument !== "") {
    const args = Object.fromEntries($argument.split("&").map(kv => kv.split("=")).map(([k, v]) => [k, decodeURIComponent(v)]));
    i = 0 != args.GPT;
    o = args.cnTimeout || 1e3;
    c = args.usTimeout || 3e3;
}

function d(code) {
    return String.fromCodePoint(...code.toUpperCase().split("").map(c => 127397 + c.charCodeAt())).replace(/🇹🇼/g, "🇨🇳");
}

async function httpAPI(path = "/v1/requests/recent", method = "GET", body = null) {
    return new Promise((res, rej) => {
        $httpAPI(method, path, body, resp => res(resp));
    });
}

async function fetchJSON(url, timeout) {
    return new Promise((resolve, reject) => {
        let finished = false;
        $httpClient.get({ url }, (error, response, data) => {
            if (finished) return;
            finished = true;
            if (error) return reject(error);
            try {
                const json = JSON.parse(data);
                resolve(json);
            } catch (e) {
                reject(e);
            }
        });
        setTimeout(() => {
            if (!finished) {
                finished = true;
                reject(new Error("Timeout"));
            }
        }, timeout);
    });
}

(async () => {
    let title = "节点信息";
    let entryText = "", exitText = "", chatGPTText = "", fullText = "";

    // 获取当前使用的节点名称（不显示策略组）
    const profile = await httpAPI("/v1/profiles");
    const nodeName = profile.proxy || "未知节点";

    // 获取落地 IP 信息
    const exitInfo = await fetchJSON("http://ip-api.com/json/?lang=zh-CN", c);
    if (exitInfo.status === "success") {
        const { country, countryCode, city, query, isp } = exitInfo;
        const flag = d(countryCode);
        exitText = `落地地区: ${flag}${country} ${city}\n落地 IP: ${query}\n落地运营商: ${isp || "未知"}\n`;
    }

    // 获取入口 IP（代理链）信息
    let remoteIP = "Noip";
    let recentRequests = (await httpAPI("/v1/requests/recent")).requests;
    let proxyUsed = recentRequests.find(r => /ip-api\.com/.test(r.URL));
    if (proxyUsed && /\(Proxy\)/.test(proxyUsed.remoteAddress)) {
        remoteIP = proxyUsed.remoteAddress.replace(" (Proxy)", "");
    }

    if (remoteIP !== "Noip") {
        const entryInfo = await fetchJSON(`https://api-v3.speedtest.cn/ip?ip=${remoteIP}`, o);
        if (entryInfo.code === 0) {
            const { countryCode, country, province, city, isp } = entryInfo.data;
            const flag = d(countryCode);
            entryText = `入口地区: ${flag}${country} ${province} ${city}\n入口 IP: ${remoteIP}\n入口运营商: ${isp || "未知"}\n`;
        } else {
            entryText = "入口信息获取失败\n";
        }
    }

    // ChatGPT 可用性
    if (i) {
        const trace = await fetchJSON("http://chat.openai.com/cdn-cgi/trace", c).catch(() => ({}));
        const restricted = ["CN", "TW", "HK", "IR", "KP", "RU", "VE", "BY"];
        if (trace && trace.loc) {
            chatGPTText = restricted.includes(trace.loc) ? `GPT: ${trace.loc} ×` : `GPT: ${trace.loc} ✓`;
            title += ` | ${chatGPTText}`;
        }
    }

    fullText = `节点信息: ${nodeName}\n\n${entryText}${exitText}`;
    a = {
        title,
        content: fullText.trim()
    };
})().catch(e => console.log(e.message)).finally(() => $done(a));
