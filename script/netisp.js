let url = "http://ip-api.com/json/?lang=zh-CN";
$httpClient.get(url, function(error, response, data){
  let jsonData = JSON.parse(data);
  let ip = jsonData.query;
  let isp = smKey(jsonData.isp);
  let country = jsonData.country;
  let city = jsonData.city;

  let content = `${country} ${city} ${ip} ${isp}`;

  body = {
    title: "𝗜𝗻𝘁𝗲𝗿𝗻𝗲𝘁 𝗦𝗲𝗿𝘃𝗶𝗰𝗲 𝗣𝗿𝗼𝘃𝗶𝗱𝗲𝗿",
    content: content
  };
  $done(body);
});

function smKey(s) {
  s = s.replace(/\s?\.?\,?(?:inc|com|llc|ltd|pte|services|network|infrastructure|limited|shanghai|proxy|corporation|communications|information|technology|id\d{2,6}|\(.+\)|\.|\,)\s?\.?/ig, "");
  if (s.length > 23) {
    return s.slice(0, 23) + "..";
  } else {
    return s;
  }
}