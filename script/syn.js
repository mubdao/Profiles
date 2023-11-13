function operator(proxies) {
  proxies.push(
    Object.assign({}, proxies[0], {
      server: "traffic-in-01.811920.xyz",
      port: 50009,
      name: "🇱🇺 LU 硝酸二甲酯 0.01x",
    })
  );
  proxies.push(
    Object.assign({}, proxies[0], {
      server: "traffic-in-01.811920.xyz",
      port: 50012,
      name: "🇸🇬 SG 苯巴比妥钠 0.01x",
    })
  );
  proxies.push(
    Object.assign({}, proxies[0], {
      server: "traffic-in-02.811920.xyz",
      port: 50013,
      name: "🇭🇰 HK 丁香酰氧胺 0.01x",
    })
  );
  return proxies;
}
