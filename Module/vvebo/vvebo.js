let url = $request.url;
let hasUid = (url) => /uid=\d+/.test(url);
let getUid = (url) => {
    let match = url.match(/uid=(\d+)/);
    return match ? match[1] : undefined;
};

if (url.includes("users/show")) {
    let uid = getUid(url);
    if (uid) $persistentStore.write(uid, "uid");
    $done({});
} else if (url.includes("statuses/user_timeline")) {
    let uid = getUid(url) || $persistentStore.read("uid");
    if (!uid) {
        $done({});
        return;
    }
    url = url.replace("statuses/user_timeline", "profile/statuses/tab")
             .replace("max_id", "since_id");
    url = url + `&containerid=230413${uid}_-_WEIBO_SECOND_PROFILE_WEIBO`;
    $done({ url });
} else if (url.includes("profile/statuses/tab")) {
    try {
        let data = JSON.parse($response.body);
        let statuses = data.cards
            .flatMap(card => card.card_group || [card])
            .filter(card => card.card_type === 9)
            .map(card => card.mblog);
        let sinceId = data.cardlistInfo?.since_id;
        $done({ body: JSON.stringify({ statuses, since_id: sinceId, total_number: 100 }) });
    } catch (e) {
        console.log(`JSON Error: ${e}`);
        $done({});
    }
} else {
    $done({});
}
