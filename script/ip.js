const timeoutAPI = 800;
let cskey = 1;

function getAPI(max = 1) {
  let url = "http://ip-api.com/json/?lang=zh-CN";
  const outnew = new Promise((resolve, reject) => {
    setTimeout(() => {
      reject(new Error("timeout"));
    }, timeoutAPI);
  });
  const renew = new Promise((resolve, reject) => {
    $httpClient.get(url, function (error, response, data) {
      if (error) {
        reject(error);
      } else {
        let key = JSON.parse(data);
        resolve(key);
      }
    });
  });
  return Promise.race([outnew, renew])
    .then((key) => {
      return key;
    })
    .catch((error) => {
      if (max > 0) {
        cskey++;
        return new Promise((resolve, reject) => {
          setTimeout(() => {
            getAPI(max - 1).then(resolve).catch(reject);
          }, 0);
        });
      } else {
        throw error;
      }
    });
}

getAPI()
  .then((key) => {
    let { query: ip, org, isp, country, city } = key;
    org = smKey(org);
    isp = smKey(isp);
    let citys = country + "-" + city;
    if (city == country) {
      citys = city;
    }
    let result = `${citys}: ${ip} ${isp}`;
    console.log(result); // 输出 IP 地址信息
  })
  .catch((error) => {
    let result = `重试${cskey}次  IP地址检测超时`;
    console.log(result); // 输出错误信息
  });

function smKey(s) {
  s = s.replace(
    /\s?\.?\,?(?:inc|com|llc|ltd|pte|services|network|infrastructure|limited|shanghai|proxy|corporation|communications|information|technology|id\d{2,6}|\(.+\)|\.|\,)\s?\.?/gi,
    ""
  );
  if (s.length > 23) {
    return s.slice(0, 23) + "..";
  } else {
    return s;
  }
}