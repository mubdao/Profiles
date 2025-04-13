async function operator(proxies = [], targetPlatform, env) {
  let args = $arguments || {}
  let scriptUrl = $script?.url || ''
  let queryArgs = {}
  if (scriptUrl.includes('?')) {
    const queryString = scriptUrl.split('?')[1]
    for (const pair of queryString.split('&')) {
      const [key, value] = pair.split('=')
      if (key && value !== undefined) {
        queryArgs[key] = decodeURIComponent(value)
      }
    }
  }
  args = { ...args, ...queryArgs }
  const { parseFlowHeaders, getFlowHeaders, flowTransfer } = flowUtils
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
    args = { ...urlArgs, ...args }
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
    let { expires, total, usage: { upload, download } } = parseFlowHeaders(subInfo)
    if (args.hideExpire) {
      expires = undefined
    }
    let expireDate = 'Never'
    if (expires && !isNaN(new Date(expires * 1000))) {
      const date = new Date(expires * 1000)
      const year = date.getFullYear()
      const month = String(date.getMonth() + 1).padStart(2, '0')
      const day = String(date.getDate()).padStart(2, '0')
      expireDate = `${year}-${month}-${day}`
    }
    let used = upload + download
    let trafficPlan
    if (total && total > 0) {
      let totalInGB = total / (1024 * 1024 * 1024)
      if (totalInGB > 1024) {
        let totalTB = (totalInGB / 1024).toFixed(2)
        let usedTB = (used / (1024 * 1024 * 1024 * 1024)).toFixed(2)
        trafficPlan = `${totalTB} TB | ${usedTB} TB`
      } else {
        let totalGB = Math.round(totalInGB)
        let usedGB = (used / (1024 * 1024 * 1024)).toFixed(2)
        trafficPlan = `${totalGB} GB | ${usedGB} GB`
      }
    } else {
      let usedInGB = used / (1024 * 1024 * 1024)
      if (usedInGB > 1024) {
        let usedTB = (usedInGB / 1024).toFixed(2)
        trafficPlan = `Unlimited | ${usedTB} TB`
      } else {
        let usedGB = usedInGB.toFixed(2)
        trafficPlan = `Unlimited | ${usedGB} GB`
      }
    }
    let resetDays = 'No Reset'
    const autoReset = (sub.autoReset ?? args.autoReset ?? true) === 'true' || (sub.autoReset ?? args.autoReset ?? true) === true
    if (autoReset && expires && !isNaN(new Date(expires * 1000))) {
      const now = new Date()
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
    const node = proxies[0] || {
      type: 'ss',
      server: '1.0.0.1',
      port: 80,
      cipher: 'aes-128-gcm',
      password: 'password',
    }
    proxies.unshift({
      ...node,
      name: `Traffic Plan: ${trafficPlan}`,
    })
    proxies.unshift({
      ...node,
      name: `Expire Date: ${expireDate}`,
    })
    if (autoReset) {
      proxies.unshift({
        ...node,
        name: `Traffic Reset: ${resetDays}`,
      })
    }
  }
  return proxies
}