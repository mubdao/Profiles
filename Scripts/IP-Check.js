let url = "http://ip-api.com/json"

$httpClient.get(url, function(error, response, data){
    let jsonData = JSON.parse(data)
    let country = jsonData.country
    let emoji = getFlagEmoji(jsonData.countryCode)
    let city = jsonData.city
    let isp = jsonData.isp
    let ip = jsonData.query
    
    body = {
        title: `${emoji} ${city}`, // 显示国旗emoji和城市名
        content: `★  ${isp} ${ip}`, // 在ISP和IP地址前添加★符号
        // icon: "globe.asia.australia.fill" // 图标暂时不显示
        titleColor: "#FFFFFF", // 标题颜色设为道奇蓝
        contentColor: "#FF7D2F" // 内容颜色设为青灰色
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
