let url = "http://ip-api.com/json"

$httpClient.get(url, function(error, response, data){
    let jsonData = JSON.parse(data)
    let country = jsonData.country
    let emoji = getFlagEmoji(jsonData.countryCode)
    let city = jsonData.city
    let isp = jsonData.isp
    let ip = jsonData.query
    
    body = {
        title: "节点信息",
        content: `IP：${ip}\nSP：${isp}\nHQ：${country} - ${city}`,    // 不显示国旗emoji
        // content: `IP：${ip}\nSP：${isp}\nHQ：${emoji}${country} - ${city}`,    // 显示国旗emoji的版本
        // icon: "globe.asia.australia.fill"    // 图标暂时不显示
    }
    $done(body);
});

function getFlagEmoji(countryCode) {
    if (countryCode.toUpperCase() == 'TW') {
        countryCode = 'CN'
    }
    const codePoints = countryCode
        .toUpperCase()
        .split('')
        .map(char => 127397 + char.charCodeAt())
    return String.fromCodePoint(...codePoints)
}
