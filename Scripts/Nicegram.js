/*

Nicegram 1.4.7

[rewrite_local]
https://nicegram.cloud/api/v6/user/info url script-response-body Vvebo-request = type=http-request,pattern=^https:\/\/api\.weibo\.cn\/2\/(users\/show\?|statuses\/user_timeline\?),requires-body=1,script-path=https://raw.githubusercontent.com/mubdao/Profiles/main/Scripts/Nicegram.js

[mitm] 
hostname = nicegram.cloud

**/

var Q = JSON.parse($response.body);
Q.data.user.lifetime_subscription = true;
Q.data.user.store_subscription = true;
Q.data.user.subscription = true;
$done({body : JSON.stringify(Q)});
