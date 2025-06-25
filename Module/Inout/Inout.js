let o = 1e3, c = 3e3, a = {};

if ("undefined" !== typeof $argument && $argument !== "") {
    const args = Object.fromEntries($argument.split("&").map(kv => kv.split("=")).map(([k, v]) => [k, decodeURIComponent(v)]));
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
    let entryText = "", exitText = "", fullText = "";

    // ✅ 主动发送一次请求，确保生成新的代理日志
    await new Promise((res) => {
        $httpClient.get({ url: "http://ip-api.com/json/?lang=zh-CN" }, () => res());
    });

    // 落地 IP 信息
    const exitInfo = await fetchJSON("http://ip-api.com/json/?lang=zh-CN", c);
    if (exitInfo.status === "success") {
        const { country, countryCode, city, query, isp } = exitInfo;
        const flag = d(countryCode);
        const locText = country === city ? country : `${country} ${city}`;
        exitText = `落地地区: ${flag} ${locText}\n落地 IP: ${query}\n落地运营商: ${isp || "未知"}\n`;
    }

    // 入口 IP 信息
    let remoteIP = "Noip";
    let recentRequests = (await httpAPI("/v1/requests/recent")).requests;
    let proxyUsed = recentRequests.find(r => /ip-api\.com/.test(r.URL));
    if (proxyUsed && /\(Proxy\)/.test(proxyUsed.remoteAddress)) {
        remoteIP = proxyUsed.remoteAddress.replace(" (Proxy)", "");
    }

    if (remoteIP !== "Noip") {
        const entryInfo = await fetchJSON(`https://api-v3.speedtest.cn/ip?ip=${remoteIP}`, o);
        if (entryInfo.code === 0) {
            const { countryCode, province, city, isp } = entryInfo.data;
            const flag = d(countryCode);
            const locText = `${province} ${city}`; // 不显示中国
            entryText = `入口地区: ${flag} ${locText}\n入口 IP: ${remoteIP}\n入口运营商: ${isp || "未知"}\n`;
        } else {
            entryText = "入口信息获取失败\n";
        }
    }

    fullText = `${entryText}\n\n${exitText}`;
    a = {
        content: fullText.trim()
    };
})().catch(e => console.log(e.message)).finally(() => $done(a));
