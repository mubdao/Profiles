**************************************

[rewrite_local]
^https?:\/\/(nicegram\.cloud\/api\/v\d\/user\/info|restore-access\.indream\.app\/restoreAccess) url script-response-body https://raw.githubusercontent.com/chxm1023/Rewrite/main/nicegram.js

[mitm]
hostname = nicegram.cloud, restore-access.indream.app

*************************************/


const url = $request.url;
const isQX = typeof $task !== "undefined";
var chxm1023 = JSON.parse($response.body);
const subscriptionTest = /https:\/\/nicegram\.cloud\/api\/v\d\/user\/info/;
const premiumTest = /https:\/\/restore-access\.indream\.app\/restoreAccess/;

if (subscriptionTest.test(url)) {
  chxm1023.data.user = {
    ...chxm1023.data.user,
    subscription: true,
    store_subscription: true,
    lifetime_subscription: true
  };
}

if (premiumTest.test(url)) {
  chxm1023["data"] = {"premiumAccess": true};
}

function finalizeResponse(content) {
  return { status: isQX ? "HTTP/1.1 200 OK" : 200, headers: $response.headers, body: JSON.stringify(content) };
}

$done(isQX ? finalizeResponse(chxm1023) : chxm1023);
