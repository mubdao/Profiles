let url = "http://ip-api.com/json/?lang=zh-CN";
$httpClient.get(url, function(error, response, data){
  let jsonData = JSON.parse(data);
  let ip = jsonData.query;
  let isp = jsonData.isp.replace(/, Inc./g, "");
  let country = jsonData.country;
  let city = jsonData.city;

  let content = `${country} ${city} ${ip} ${getOrganization(isp)}`;

  body = {
    title: "𝗜𝗻𝘁𝗲𝗿𝗻𝗲𝘁 𝗦𝗲𝗿𝘃𝗶𝗰𝗲 𝗣𝗿𝗼𝘃𝗶𝗱𝗲𝗿",
    content: content
  };
  $done(body);
});

function getOrganization(isp) {
  let organizations = isp.split(",");
  let filteredOrganizations = organizations.slice(0, 2).map(org => org.trim());
  return filteredOrganizations.join(", ");
}