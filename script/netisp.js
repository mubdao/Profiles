let url = "http://ip-api.com/json/?lang=zh-CN";
$httpClient.get(url, function(error, response, data){
  let jsonData = JSON.parse(data);
  let ip = jsonData.query;
  let isp = jsonData.isp.replace(/, Inc./g, "");
  let country = jsonData.country;
  let city = jsonData.city;

  let ispParts = isp.split(" ");
  isp = ispParts.slice(0, 2).join(" ");

  let content = `${country}, ${city}\n${ip}\n${isp}`;

  body = {
    title: "𝗜𝗻𝘁𝗲𝗿𝗻𝗲𝘁 𝗦𝗲𝗿𝘃𝗶𝗰𝗲 𝗣𝗿𝗼𝘃𝗶𝗱𝗲𝗿",
    content: content
  };
  $done(body);
});