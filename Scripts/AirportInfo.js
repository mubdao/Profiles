let args = getArgs();

(async () => {
  let info = await getDataInfo(args.url);
  if (!info) $done();

  let used = info.download + info.upload;
  let total = info.total;
  let expire = args.expire || info.expire;

  let content = [`📊：${bytesToSize(used)} | ${bytesToSize(total)}`];

  if (expire && expire !== "false") {
    if (/^[\d.]+$/.test(expire)) expire *= 1000;
  }

  if (args["reset_day"] && parseInt(args["reset_day"]) > 0) {
    let resetDayLeft = getRemainingDays(parseInt(args["reset_day"]));
    content.push(`⏳：${resetDayLeft}天 | ${formatTime(expire)}`);
  } else {
    content.push(`⏳：${formatTime(expire)}`);
  }

  let now = new Date();
  let hour = now.getHours();
  let minutes = now.getMinutes();
  hour = hour > 9 ? hour : "0" + hour;
  minutes = minutes > 9 ? minutes : "0" + minutes;

  $done({
    title: `${args.title} | ${hour}:${minutes}`,
    content: content.join("\n"),
    // icon: args.icon || "airplane.circle",
    // "icon-color": args.color || "#007aff",
  });
})();

function getArgs() {
  return Object.fromEntries(
    $argument
      .split("&")
      .map((item) => item.split("="))
      .map(([k, v]) => [k, decodeURIComponent(v)])
  );
}

function getUserInfo(url) {
  let method = args.method || "head";
  let request = { headers: { "User-Agent": "Quantumult%20X" }, url };
  return new Promise((resolve, reject) =>
    $httpClient[method](request, (err, resp) => {
      if (err != null) {
        reject(err);
        return;
      }
      if (resp.status !== 200) {
        reject(resp.status);
        return;
      }
      let header = Object.keys(resp.headers).find(key => key.toLowerCase() === "subscription-userinfo");
      if (header) {
        resolve(resp.headers[header]);
        return;
      }
      reject("链接响应头不带有流量信息");
    })
  );
}

async function getDataInfo(url) {
  const [err, data] = await getUserInfo(url)
    .then(data => [null, data])
    .catch(err => [err, null]);
  if (err) {
    console.log(err);
    return;
  }

  return Object.fromEntries(
    data
      .match(/\w+=[\d.eE+-]+/g)
      .map(item => item.split("="))
      .map(([k, v]) => [k, Number(v)])
  );
}

function getRemainingDays(resetDay) {
  if (!resetDay) return 0;

  let now = new Date();
  let today = now.getDate();
  let month = now.getMonth();
  let year = now.getFullYear();
  let daysInMonth = new Date(year, month + 1, 0).getDate();

  if (resetDay >= today) {
    return resetDay - today;
  } else {
    return daysInMonth - today + resetDay;
  }
}

function bytesToSize(bytes) {
  if (bytes === 0) return "0B";
  let k = 1024;
  let sizes = ["B", "KB", "MB", "GB", "TB", "PB", "EB", "ZB", "YB"];
  let i = Math.floor(Math.log(bytes) / Math.log(k));
  return (bytes / Math.pow(k, i)).toFixed(2) + " " + sizes[i];
}

function formatTime(time) {
  let dateObj = new Date(time);
  let year = dateObj.getFullYear();
  let month = dateObj.getMonth() + 1;
  let day = dateObj.getDate();
  return year + "年" + month + "月" + day + "日";
}
