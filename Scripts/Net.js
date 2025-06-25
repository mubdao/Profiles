// @timestamp thenkey 2024-01-31 13:54:57
let i = !1,
    o = 1e3,
    c = 3e3,
    a = {};

if ("undefined" != typeof $argument && "" !== $argument) {
    const n = l($argument);
    i = "1" === n.GPT || "true" === n.GPT, 
    o = n.cnTimeout ? parseInt(n.cnTimeout) : 1e3, 
    c = n.usTimeout ? parseInt(n.usTimeout) : 3e3;
}

function l(e) {
    return Object.fromEntries(
        e.split("&").map(item => {
            const [key, value] = item.split("=");
            return [key, decodeURIComponent(value || "")];
        })
    );
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
    
    // 获取落地信息
    try {
        const P = await m("http://ip-api.com/json/?lang=zh-CN", c);
        if (P.status === "success") {
            const { country, countryCode, regionName, city, query, isp } = P;
            n = query;
            const region = `${d(countryCode)} ${country}${city && city !== country ? " " + city : ""}`;
            p = `落地地区: ${region}\n落地 IP: ${query}\n落地运营商: ${isp}`;
        }
    } catch (e) {
        console.log(`落地信息错误: ${e}`);
    }
    
    // GPT检测
    if (i) {
        try {
            const trace = await m("http://chat.openai.com/cdn-cgi/trace", c);
            if (typeof trace === "object" && trace.loc) {
                const blocked = ["CN", "TW", "HK", "IR", "KP", "RU", "VE", "BY"].includes(trace.loc);
                l = `GPT: ${trace.loc} ${blocked ? "×" : "✓"}`;
            }
        } catch (e) {
            console.log(`GPT检测错误: ${e}`);
        }
    }
    
    // 获取入口信息
    let entryIP = "";
    try {
        const requests = (await g()).requests;
        const recent = requests.slice(0, 6).find(r => /ip-api\.com/.test(r.URL));
        
        if (recent) {
            entryIP = recent.remoteAddress.replace(" (Proxy)", "");
            
            // 国内IP检测
            if (/^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$/.test(entryIP)) {
                try {
                    const cnResponse = await m(`https://api-v3.speedtest.cn/ip?ip=${entryIP}`, o);
                    if (cnResponse.code === 0 && cnResponse.data.country === "中国") {
                        const { province, city, isp, countryCode } = cnResponse.data;
                        const region = `${d(countryCode)} ${province}${city && city !== province ? " " + city : ""}`;
                        f = `入口地区: ${region}\n入口 IP: ${entryIP}\n入口运营商: ${isp}`;
                    }
                } catch (e) {
                    console.log(`国内API错误: ${e}`);
                }
            }
            
            // 国际IP检测
            if (!f && entryIP !== n) {
                try {
                    const intlResponse = await m(`http://ip-api.com/json/${entryIP}?lang=zh-CN`, c);
                    if (intlResponse.status === "success") {
                        const { country, countryCode, city, isp } = intlResponse;
                        const region = `${d(countryCode)} ${country}${city && city !== country ? " " + city : ""}`;
                        f = `入口地区: ${region}\n入口 IP: ${entryIP}\n入口运营商: ${isp}`;
                    }
                } catch (e) {
                    console.log(`国际API错误: ${e}`);
                }
            }
        }
    } catch (e) {
        console.log(`入口信息错误: ${e}`);
    }
    
    // 处理直连情况
    if (entryIP === n && p) {
        f = "连接类型: 直连";
    }
    
    // 构建最终结果
    a = {
        title: l || "节点信息",
        content: [f, p].filter(Boolean).join("\n\n")
    };
})().catch(e => {
    console.log(`全局错误: ${e}`);
    a = {
        title: "脚本错误",
        content: e.message || String(e)
    };
}).finally(() => $done(a));
