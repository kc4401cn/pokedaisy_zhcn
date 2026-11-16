#!/usr/bin/env bash
# Bring dev-zh up to a new upstream release, and say what still needs a translation.
#
#   bash scripts/sync-upstream.sh           # report only: what upstream added, what to bump
#   bash scripts/sync-upstream.sh --sync    # fetch + rebase + bump versionCode
#   bash scripts/sync-upstream.sh --bump    # only fix versionCode / versionName
#   bash scripts/sync-upstream.sh --todo    # only list the missing Chinese
#
# The one number that must not be guessed: versionCode has to be one past BOTH upstream's
# and this build's last one, or Android refuses the upgrade - or the updater reads it as
# the same version and never offers it. That is worked out here rather than by hand.
set -euo pipefail

cd "$(dirname "${BASH_SOURCE[0]}")/.."

BRANCH=dev-zh
GRADLE=app/build.gradle.kts
CHECK=scripts/check_translations.py
UPSTREAM=${UPSTREAM_REF:-origin/main}   # overridable, e.g. UPSTREAM_REF=test/foo for a dry run

field() { git show "$1:$GRADLE" | grep -oE "version$2 = [^ ]+" | tail -1 | sed 's/.*= //; s/"//g'; }

report() {
  local uvc lvc uvn behind ahead
  uvc=$(field "$UPSTREAM" Code); lvc=$(field "$BRANCH" Code); uvn=$(field "$UPSTREAM" Name)
  behind=$(git rev-list --count "$BRANCH..$UPSTREAM")
  ahead=$(git rev-list --count "$UPSTREAM..$BRANCH")

  echo "上游 $UPSTREAM"
  echo "  $(git log -1 --format='%h %s' "$UPSTREAM" | cut -c1-66)"
  echo "  版本 $uvn  versionCode $uvc"
  echo "本地 $BRANCH  versionCode $lvc"
  echo
  echo "落后上游 $behind 个提交，本地有 $ahead 个汉化提交"

  if [ "$behind" -eq 0 ]; then
    echo "→ 上游没有新版本，不用跟。"
    return 0
  fi

  echo
  echo "上游新增："
  git log --format='  %h %s' --no-merges "$BRANCH..$UPSTREAM" | head -20
  echo
  echo "要改的版本号："
  echo "  versionCode  $lvc → $(( (uvc > lvc ? uvc : lvc) + 1 ))   （上游 $uvc 与本地 $lvc 取大，再 +1）"
  echo "  versionName  → $uvn"
}

bump() {
  if [ "$(git rev-list --count "$BRANCH..$UPSTREAM")" -eq 0 ]; then
    echo "上游没有新提交，versionCode 不用动。真要改就手工编辑 $GRADLE。"
    return 0
  fi
  local uvc lvc nvc uvn
  uvc=$(field "$UPSTREAM" Code); lvc=$(field "$BRANCH" Code); uvn=$(field "$UPSTREAM" Name)
  nvc=$(( (uvc > lvc ? uvc : lvc) + 1 ))

  python3 - "$GRADLE" "$nvc" "$uvn" <<'PY'
import re, sys
path, vc, vn = sys.argv[1], sys.argv[2], sys.argv[3]
s = open(path, encoding='utf-8').read()
s, n1 = re.subn(r'versionCode = \d+', 'versionCode = ' + vc, s, count=1)
s, n2 = re.subn(r'versionName = "[^"]+"', 'versionName = "%s"' % vn, s, count=1)
assert n1 == 1 and n2 == 1, 'versionCode/versionName not found in ' + path
open(path, 'w', encoding='utf-8', newline='\n').write(s)
print('  versionCode → %s' % vc)
print('  versionName → "%s"' % vn)
PY
  echo
  echo "未提交的改动："
  git diff --stat "$GRADLE" | sed 's/^/  /'
  echo "（顺手把注释里 'One past upstream's <旧值>' 的旧值改掉，再 commit）"
}

todo() {
  echo "=== 中文缺哪些（只有 --zh 会看中文）==="
  python3 "$CHECK" --zh 2>&1 | tail -20
  echo
  echo "=== 还要人看的两处 ==="
  echo "  1. 上游新增的 GUIDE 行："
  echo "     ./gradlew :app:testDebugUnitTest --tests '*GuideTranslationsTest*'"
  echo "     它会把缺的行写到 app/build/guide-missing/。"
  echo "  2. 上游若加了新物种/招式/道具，GameNamesZh 与 DexTextZh 不会自己跟上，"
  echo "     需要从 zh-i18n 重新生成（见 docs/ZH_HANS_DATA_SOURCES.md）。"
  echo
  echo "=== 发版时 ==="
  echo "  tag 必须带 -zh（v1.5.2-zh），且不要勾 pre-release —— 否则更新器要么跳过它，"
  echo "  要么把英文版当新版推给中文用户。详见 docs：Publishing a release。"
}

sync() {
  if [ -n "$(git status --porcelain)" ]; then
    echo "工作区不干净，先提交或 stash：" >&2
    git status --short >&2
    exit 1
  fi
  git fetch origin --prune
  report
  if [ "$(git rev-list --count "$BRANCH..$UPSTREAM")" -eq 0 ]; then exit 0; fi

  echo
  echo "=== rebase $BRANCH 到 $UPSTREAM ==="
  git checkout -q "$BRANCH"
  if git rebase "$UPSTREAM"; then
    echo "rebase 完成。"
  else
    cat <<'EOF'

停在上面的冲突上。通常只有一处：app/build.gradle.kts 的 versionCode / versionName，
因为上游每次发版都改那里，本 fork 的发行配置也改。

  1. versionName 用上游的
  2. versionCode 改成「上游与本地取大，再 +1」
  3. 保留这两行（本 fork 的发行配置）：
         applicationIdSuffix = zhAppIdSuffix
         versionNameSuffix = zhVersionSuffix
  4. git add app/build.gradle.kts && git rebase --continue
  5. bash scripts/sync-upstream.sh --bump

放弃：git rebase --abort
EOF
    exit 1
  fi
  bump
  echo
  todo
}

case "${1:---report}" in
  --report) report ;;
  --bump)   bump ;;
  --todo)   todo ;;
  --sync)   sync ;;
  *) echo "用法: $0 [--report|--sync|--bump|--todo]" >&2; exit 2 ;;
esac
