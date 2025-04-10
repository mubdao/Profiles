async function operator(proxies = [], targetPlatform, env) {
  let args = $arguments || {}
  const {
    parseFlowHeaders,
    getFlowHeaders,
    flowTransfer
  } = flowUtils
  const sub = env.source[proxies?.[0]?._subName || proxies?.[0]?.subName]
  let subInfo
  if (sub.source === 'local' && !['localFirst', 'remoteFirst'].includes(sub.mergeSources)) {
    if (sub.subUserinfo) {
      if (/^https?:\/\//.test(sub.subUserinfo)) {
        subInfo = await getFlowHeaders(undefined, undefined, undefined, sub.proxy, sub.subUserinfo)
      } else {
        subInfo = sub.subUserinfo
      }
    }
  } else {
    let url = `${sub.url}`
      .split(/[\r\n]+/)
      .map(i => i.trim())
      .filter(i => i.length)?.[0]
    let urlArgs = {}
    const rawArgs = url.split('#')
    url = url.split('#')[0]
    if (rawArgs.length > 1) {
      try {
        urlArgs = JSON.parse(decodeURIComponent(rawArgs[1]))
      } catch (e) {
        for (const pair of rawArgs[1].split('&')) {
          const key = pair.split('=')[0]
          const value = pair.split('=')[1]
          urlArgs[key] = value == null || value === '' ? true : decodeURIComponent(value)
        }
      }
    }
    args = {
      ...urlArgs,
      ...args
    }
    if (!args.noFlow) {
      if (sub.subUserinfo) {
        if (/^https?:\/\//.test(sub.subUserinfo)) {
          subInfo = await getFlowHeaders(undefined, undefined, undefined, sub.proxy, sub.subUserinfo)
        } else {
          subInfo = sub.subUserinfo
        }
      } else {
        subInfo = await getFlowHeaders(url)
      }
    }
  }
  if (subInfo) {
    let {
      expires,
      total,
      usage: {
        upload,
        download
      },
    } = parseFlowHeaders(subInfo)
    if (args.hideExpire) {
      expires = undefined
    }
    let expireDate = 'N/A'
    if (expires) {
      const date = new Date(expires * 1000)
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      expireDate = `${year}-${month}-${day}`
    }
    let used = upload + download
    const usedGB = (used / 1024 / 1024 / 1024).toFixed(2)
    const totalGB = Math.round(total / 1024 / 1024 / 1024)
    let resetDays = 'N/A'
    const now = new Date()
    if (expires) {
      const expireTime = new Date(expires * 1000)
      const resetDay = expireTime.getDate()
      let nextReset = new Date(now)
      nextReset.setDate(resetDay)
      nextReset.setHours(0, 0, 0, 0)
      if (nextReset < now) {
        nextReset.setMonth(nextReset.getMonth() + 1)
      }
      if (nextReset > expireTime) {
        resetDays = 'N/A'
      } else if (nextReset.toDateString() === now.toDateString()) {
        resetDays = 'Today'
      } else {
        const daysLeft = Math.ceil((nextReset - now) / (1000 * 60 * 60 * 24))
        resetDays = `${daysLeft} Days Left`
      }
    }
    const node = proxies[proxies.length - 1] || {
      type: 'ss',
      server: '1.0.0.1',
      port: 80,
      cipher: 'aes-128-gcm',
      password: 'password',
    }
    proxies.unshift({
      ...node,
      name: `Expire Date: ${expireDate}`,
    })
    proxies.unshift({
      ...node,
      name: `Traffic Reset: ${resetDays}`,
    })
    proxies.unshift({
      ...node,
      name: `Traffic Plan: ${totalGB} GB | ${usedGB} GB`,
    })
  }
  return proxies
}