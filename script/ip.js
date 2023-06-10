const timeoutGPT = 500;
const timeoutAPI = 800;
let cskey = 1, gkey = 1, body = {};

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

function getGPT(cs = 1) {
  let url = "http://chat.openai.com/cdn-cgi/trace";
  const outnew = new Promise((resolve, reject) => {
    setTimeout(() => {
      reject(new Error("timeout"));
    }, timeoutGPT);
  });
  const renew = new Promise((resolve, reject) => {
    $httpClient.get(url, function (error, response, data) {
      if (error) {
        reject(error);
      } else {
        let lines = data.split("\n");
        let key = lines.reduce((acc, line) => {
          let [key, value] = line.split("=");
          acc[key] = value;
          return acc;
        }, {});
        resolve(key);
      }
    });
  });
  return Promise.race([outnew, renew])
    .then((key) => {
      return key;
    })
    .catch((error) => {
      if (cs > 0) {
        gkey++;
        return new Promise((resolve, reject) => {
          setTimeout(() => {
            getGPT(cs - 1).then(resolve).catch(reject);
          }, 0);
        });
      } else {
        throw error;
      }
    });
}

getAPI()
  .then((api) => {
    let { query: ip, country, city } = api;

    getGPT()
      .then((gpt) => {
        let loc = gpt.loc;
        let supported = loc.includes(country) || loc.includes(city);

        let output = `IP: ${ip}  ChatGPT: ${supported ? "✓" : "×"}`;
        console.log(output);
      })
      .catch((error) => {
        console.log(`重试${gkey}次  ChatGPT不支持`);
      });
  })
  .catch((error) => {
    console.log(`重试${cskey}次  IPAPI检测超时`);
  });
