/*
解锁EmbyPremium @RuCu6

[MITM]
hostname = mb3admin.com

QuantumultX:
^https?:\/\/mb3admin.com\/admin\/service\/registration\/validateDevice url script-response-body https://raw.githubusercontent.com/mubdao/Profiles/main/script/emby.js

Surge:
Emby= type=http-response,pattern=^https?:\/\/mb3admin.com\/admin\/service\/registration\/validateDevice,requires-body=1,max-size=0,script-path=https://raw.githubusercontent.com/mubdao/Profiles/main/script/emby.js
*/


var $util = util();

if ($request.url.indexOf("mb3admin.com/admin/service/registration/validateDevice") != -1) {
  if ($util.status != 200) {
    $done({
      status: "HTTP/1.1 200 OK",
      headers: $response.headers,
      body: '{"cacheExpirationDays":999,"resultCode":"GOOD","message":"Device Valid"}'
    });
  } else {
    $done({});
  }
} else {
  $done({});
}

function util() {
  const isRequest = typeof $request != "undefined";
  const isSurge = typeof $httpClient != "undefined";
  const isQuanX = typeof $task != "undefined";
  const notify = (title, subtitle = "", message = "") => {
    if (isQuanX) $notify(title, subtitle, message);
    if (isSurge) $notification.post(title, subtitle, message);
  };
  const write = (value, key) => {
    if (isQuanX) return $prefs.setValueForKey(value, key);
    if (isSurge) return $persistentStore.write(value, key);
  };
  const read = (key) => {
    if (isQuanX) return $prefs.valueForKey(key);
    if (isSurge) return $persistentStore.read(key);
  };
  const adapterStatus = (response) => {
    if (response) {
      if (response.status) {
        response["statusCode"] = response.status;
      } else if (response.statusCode) {
        response["status"] = response.statusCode;
      }
    }
    return response;
  };
  const get = (options, callback) => {
    if (isQuanX) {
      if (typeof options == "string")
        options = {
          url: options,
          method: "GET"
        };
      $task.fetch(options).then(
        (response) => {
          callback(null, adapterStatus(response), response.body);
        },
        (reason) => callback(reason.error, null, null)
      );
    }
    if (isSurge)
      $httpClient.get(options, (error, response, body) => {
        callback(error, adapterStatus(response), body);
      });
  };
  const post = (options, callback) => {
    if (isQuanX) {
      if (typeof options == "string")
        options = {
          url: options,
          method: "POST"
        };
      $task.fetch(options).then(
        (response) => {
          callback(null, adapterStatus(response), response.body);
        },
        (reason) => callback(reason.error, null, null)
      );
    }
    if (isSurge) {
      $httpClient.post(options, (error, response, body) => {
        callback(error, adapterStatus(response), body);
      });
    }
  };
  const done = (value = {}) => {
    if (isQuanX) return $done(value);
    if (isSurge) isRequest ? $done(value) : $done();
  };
  const status = isQuanX ? $response.statusCode : $response.status;
  return {
    isRequest,
    notify,
    write,
    read,
    get,
    post,
    done,
    status
  };
}