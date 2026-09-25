/**
 * 连接列表：直接读取 src/连接配置.json
 * —— 要改地址 / 加连接，只改那个 JSON，然后运行「构建」脚本即可。
 *
 * 说明：本机型桌面卡片不支持存储/文件读写，配置在构建时打包进卡片，
 * 因此修改 JSON 后需要重新构建并重装。
 */

import config from '../连接配置.json'

function normalize(list) {
  const out = []
  ;(list || []).forEach((c, i) => {
    if (!c || !c.ip) return
    out.push({
      id: i + 1,
      name: c.name || ('连接' + (i + 1)),
      ip: ('' + c.ip).trim(),
      port: (c.port !== undefined && c.port !== null && ('' + c.port).trim() !== '') ? ('' + c.port).trim() : '8787',
      path: c.path ? ('' + c.path).trim() : ''
    })
  })
  return out
}

export const ENDPOINTS = normalize(config && config.connections)
