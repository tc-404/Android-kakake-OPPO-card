#!/usr/bin/env bash
# kakake 远程监控 · 一键构建（macOS / Linux）
cd "$(dirname "$0")"
export npm_config_cache="$(pwd)/.npm-cache"

CY=$'\033[36m'; GY=$'\033[90m'; GR=$'\033[32m'; RD=$'\033[31m'; YL=$'\033[33m'; WT=$'\033[97m'; DC=$'\033[36m'; RS=$'\033[0m'
RULE="    ──────────────────────────────────────────"

printf '\n'
printf '    %s▌%s %skakake%s %s远程监控%s\n' "$CY" "$RS" "$WT" "$RS" "$WT" "$RS"
printf '    %s▌%s %sQuickApp Desktop Widget%s\n' "$CY" "$RS" "$GY" "$RS"
printf '%s%s%s\n\n' "$DC" "$RULE" "$RS"

LOG=/tmp/kakake_build.log

spin() {
  local title="$1"; shift
  "$@" >"$LOG" 2>&1 &
  local pid=$!
  local frames='|/-\'; local i=0; local start=$SECONDS
  while kill -0 "$pid" 2>/dev/null; do
    local f=${frames:$((i%4)):1}
    printf '\r    %s%s%s  %s   %ss   ' "$CY" "$f" "$RS" "$title" "$((SECONDS-start))"
    sleep 0.1; i=$((i+1))
  done
  wait "$pid"; return $?
}

# ---- 1/3 依赖 ----
if [ ! -f node_modules/hap-toolkit/bin/index.js ]; then
  spin "[1/3] 安装依赖 (首次较慢)" npm install
  if [ ! -f node_modules/hap-toolkit/bin/index.js ]; then
    printf '\r    %sx  [1/3] 安装依赖失败%s\n' "$RD" "$RS"
    printf '       请检查网络后重试。\n'; exit 1
  fi
  printf '\r    %s✔%s  [1/3] 安装依赖              \n' "$GR" "$RS"
else
  printf '    %s✔%s  [1/3] 依赖已就绪\n' "$GR" "$RS"
fi

# ---- 2/3 构建 ----
spin "[2/3] 编译打包" node node_modules/hap-toolkit/bin/index.js build
if ! ls dist/*.rpk >/dev/null 2>&1; then
  printf '\r    %sx  [2/3] 编译打包失败%s\n' "$RD" "$RS"
  tail -n 15 "$LOG" | sed 's/^/       /'; exit 1
fi
printf '\r    %s✔%s  [2/3] 编译打包              \n' "$GR" "$RS"

# ---- 3/3 产物 ----
mkdir -p 成品; rm -f 成品/*.rpk; mv -f dist/*.rpk 成品/; rm -rf dist build
printf '    %s✔%s  [3/3] 整理产物\n' "$GR" "$RS"

RPK=$(ls 成品/*.rpk 2>/dev/null | head -1)
SIZE=$(du -k "$RPK" 2>/dev/null | cut -f1)
printf '\n%s%s%s\n' "$DC" "$RULE" "$RS"
printf '     %s[ 完成 ]%s\n' "$GR" "$RS"
printf '       %s安装包%s  %s\n' "$GY" "$RS" "$RPK"
printf '       %s大小%s    %s KB\n' "$GY" "$RS" "$SIZE"
printf '%s%s%s\n\n' "$DC" "$RULE" "$RS"
