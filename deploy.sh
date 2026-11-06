#!/usr/bin/env bash
# 一键部署到 GitHub Pages
# 用法： GITHUB_TOKEN=xxx REPO_NAME=canyun-om-agent ./deploy.sh
set -euo pipefail

: "${GITHUB_TOKEN:?请先设置 GITHUB_TOKEN 环境变量}"
REPO_NAME="${REPO_NAME:-canyun-om-agent}"
DESC="载运运维检测智能体 · 前端原型"
API="https://api.github.com"
DIR="$(cd "$(dirname "$0")" && pwd)"
cd "$DIR"

jget() { python -c "import sys,json;d=json.load(sys.stdin);print(d.get('$1',''))" 2>/dev/null || true; }

echo "→ 校验 token"
ME=$(curl -sf -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" "$API/user") || {
  echo "token 无效或已过期"; exit 1;
}
LOGIN=$(printf '%s' "$ME" | jget login)
echo "  账号：$LOGIN"

echo "→ 创建仓库 $REPO_NAME（若已存在则复用）"
curl -s -o /dev/null -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/user/repos" -d "{\"name\":\"$REPO_NAME\",\"description\":\"$DESC\",\"private\":false,\"auto_init\":false}" | {
  read -r code; echo "  HTTP $code";
}

echo "→ 提交"
git config user.name "$LOGIN"
git config user.email "$LOGIN@users.noreply.github.com"
git add -A
git -c core.quotepath=false commit -m "feat: 载运运维检测智能体控制台原型" >/dev/null 2>&1 || echo "  无新改动"
git branch -M main

echo "→ 推送"
git remote remove origin 2>/dev/null || true
git push --quiet --force "https://x-access-token:${GITHUB_TOKEN}@github.com/${LOGIN}/${REPO_NAME}.git" main:main
git remote add origin "https://github.com/${LOGIN}/${REPO_NAME}.git"

echo "→ 开启 Pages"
code=$(curl -s -o /tmp/pages.json -w "%{http_code}" -X POST \
  -H "Authorization: Bearer $GITHUB_TOKEN" -H "Accept: application/vnd.github+json" \
  "$API/repos/${LOGIN}/${REPO_NAME}/pages" \
  -d '{"source":{"branch":"main","path":"/"}}')
if [ "$code" != "201" ] && [ "$code" != "409" ]; then
  echo "  创建 Pages 返回 $code："; cat /tmp/pages.json; echo
fi
if [ "$code" = "409" ]; then
  curl -s -o /dev/null -X PUT -H "Authorization: Bearer $GITHUB_TOKEN" \
    -H "Accept: application/vnd.github+json" \
    "$API/repos/${LOGIN}/${REPO_NAME}/pages" \
    -d '{"source":{"branch":"main","path":"/"}}'
  echo "  Pages 已存在，已更新为 main 分支"
fi

echo
echo "完成。约 1 分钟后可访问："
echo "  https://${LOGIN}.github.io/${REPO_NAME}/"
echo "仓库："
echo "  https://github.com/${LOGIN}/${REPO_NAME}"
