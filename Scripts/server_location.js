if ($response.statusCode != 200) {
  $done(null);
}

const city0 = "高谭市";
const isp0 = "Cross-GFW.org";
const MAX_LENGTH = 10;
const TRUNCATE_LENGTH = 7;

let body = $response.body;
let obj = JSON.parse(body);
if (obj.data) obj = obj.data;

let countryCode = obj['countryCode'] || obj['loc'] || 'UNKNOWN';
let city = city_check(obj['city']);
let isp = isp_check(obj['isp']);
let query = obj['query'] || 'Unknown IP';
let regionName = city_check(obj['regionName'] || obj['region']);

let title = d(countryCode) + ' ' + city;
let subtitle = truncate_isp(isp) + ' ' + query;
let ip = query;
let description = '服务商：' + truncate_isp(isp) + '\n' +
                 '地区：' + regionName + '\n' +
                 'IP：' + query;

$done({title, subtitle, ip, description});

function city_check(para) {
  return para || city0;
}

function isp_check(para) {
  return para || isp0;
}

function truncate_isp(para) {
  let width = 0;
  let result = '';
  for (let i = 0; i < para.length; i++) {
    width += /[\u4e00-\u9fff]/.test(para[i]) ? 2 : 1;
    if (width > MAX_LENGTH) {
      return result.substring(0, Math.max(0, result.length - (width - TRUNCATE_LENGTH))) + '...';
    }
    result += para[i];
  }
  return result;
}

function d(e) {
  const t = e.toUpperCase().split("").map(char => 127397 + char.charCodeAt());
  return String.fromCodePoint(...t).replace(/🇹🇼/g, "🇨🇳") || '🌐';
}
