/**
 * 咔咔珂 · 外放 API 对接（只读）
 * HTTP： GET http://<IP>:<端口>/api/public   （请求一次拿一次快照，路径内置）
 * 页面与卡片共用这份逻辑。
 */

import fetch from '@system.fetch'

const DEFAULT_PORT = '8787'
const API_PATH = '/api/public'

function portOf(conn) {
  const port = conn && conn.port
  return (port !== undefined && port !== null && ('' + port).trim() !== '') ? ('' + port).trim() : DEFAULT_PORT
}

function pathOf(conn) {
  return (conn && conn.path) ? conn.path : API_PATH
}

/** 生成连接 URL */
export function buildUrl(conn) {
  return 'http://' + conn.ip + ':' + portOf(conn) + pathOf(conn)
}

/** 解析返回体（字符串则 JSON.parse） */
function parseData(raw) {
  let data = raw
  if (typeof raw === 'string') {
    try { data = JSON.parse(raw) } catch (e) { data = null }
  }
  return data
}

/** 拉取单个连接，永不抛错：成功返回 { conn, data }，失败/不可达返回 { conn, error } */
export function fetchOne(conn) {
  return new Promise((resolve) => {
    if (!conn || !conn.ip) {
      resolve({ conn: conn, error: 'no-ip' })
      return
    }
    fetch.fetch({
      url: buildUrl(conn),
      method: 'GET',
      responseType: 'json',
      success: (resp) => {
        const code = resp && resp.code
        const data = parseData(resp && resp.data)
        if (code === 200 && data && data.ok) {
          resolve({ conn: conn, data: data })
        } else if (code === 403) {
          resolve({ conn: conn, error: 'closed' })
        } else {
          resolve({ conn: conn, error: 'bad-' + code })
        }
      },
      fail: () => resolve({ conn: conn, error: 'unreachable' })
    })
  })
}

/** 拉取全部连接 */
export function fetchAll(connections) {
  const list = connections || []
  return Promise.all(list.map((c) => fetchOne(c)))
}

/** 把多个连接的结果聚合成桌面卡片用的快照（全部连接的全部账号合并） */
export function aggregate(results) {
  const accounts = []
  let totalReceived = 0
  let totalSent = 0
  let maxSec = -1
  let uptimeText = '—'
  let onlineCount = 0
  let reachableCount = 0

  ;(results || []).forEach((r) => {
    if (!r || !r.data) return
    const d = r.data
    reachableCount++
    totalReceived += (d.logs && d.logs.received) || 0
    totalSent += (d.logs && d.logs.sent) || 0
    const sec = (d.uptime && d.uptime.seconds) || 0
    if (sec > maxSec) {
      maxSec = sec
      uptimeText = (d.uptime && d.uptime.text) || '—'
    }
    const arr = (d.accounts && d.accounts.list) || []
    const cRecv = (d.logs && d.logs.received) || 0
    const cSent = (d.logs && d.logs.sent) || 0
    const cUpSec = (d.uptime && d.uptime.seconds) || 0
    const cUpText = (d.uptime && d.uptime.text) || ''
    arr.forEach((a) => {
      if (a.phase === 'connected') onlineCount++
      accounts.push({
        name: a.name || '未命名',
        avatar: a.avatar || '',
        phase: a.phase || 'disabled',
        phaseText: a.phaseText || phaseTextOf(a.phase),
        typeText: a.typeText || '',
        received: cRecv,
        sent: cSent,
        uptimeSec: cUpSec,
        uptimeText: cUpText
      })
    })
  })

  return {
    accounts: accounts,
    totalReceived: totalReceived,
    totalSent: totalSent,
    uptimeText: uptimeText,
    uptimeSec: maxSec > 0 ? maxSec : 0,
    onlineCount: onlineCount,
    reachableCount: reachableCount,
    updatedAt: Date.now()
  }
}

export function phaseColor(phase) {
  switch (phase) {
    case 'connected': return '#34d399'
    case 'reconnecting': return '#fbbf24'
    case 'failed': return '#f87171'
    default: return '#8b97a6'
  }
}

export function phaseTextOf(phase) {
  switch (phase) {
    case 'connected': return '已连接'
    case 'reconnecting': return '连接中'
    case 'failed': return '连接失败'
    case 'disabled': return '已关闭'
    default: return '未知'
  }
}

/** 数量格式化：128 -> "128"，12438 -> "12.4k" */
export function fmtCount(n) {
  n = n || 0
  if (n >= 10000) return (n / 1000).toFixed(1) + 'k'
  if (n >= 1000) return (n / 1000).toFixed(2) + 'k'
  return '' + n
}

/** 蜡缩短运行时长文本：优先返回 API 的可读串，过长时截断 */
export function shortUptime(text) {
  return text || '—'
}

/** 由秒数生成卡片用的紧凑运行时长：3661 -> "1h" */
export function shortDur(sec) {
  sec = sec || 0
  if (sec < 60) return sec + 's'
  if (sec < 3600) return Math.floor(sec / 60) + 'm'
  if (sec < 86400) return Math.floor(sec / 3600) + 'h'
  return Math.floor(sec / 86400) + 'd'
}
