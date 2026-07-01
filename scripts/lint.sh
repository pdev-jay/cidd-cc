#!/usr/bin/env bash
# 플러그인 소스(agents/*.md, skills/*/SKILL.md) 정합성 검사.
# 과거 실제 사고 재발 방지: dangling reference(GOAL.md 삭제 후 참조 남음),
# workflows/ 폴더가 동명 skill과 충돌해 잘못된 파일이 실행된 버그.
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$repo_root" || exit 1

errors=0

fail() {
    echo "ERROR: $1"
    errors=$((errors + 1))
}

frontmatter() {
    # 파일의 첫 --- ~ 다음 --- 사이만 뽑는다.
    awk 'NR==1{if ($0!="---"){exit 1} next} /^---$/{exit} {print}' "$1"
}

# ── 1. agents/*.md frontmatter ──────────────────────────────────
for f in agents/*.md; do
    [ -e "$f" ] || continue
    fm="$(frontmatter "$f")"
    if [ -z "$fm" ] && ! head -n1 "$f" | grep -q '^---$'; then
        fail "$f: frontmatter 없음(--- 로 시작 안 함)"
        continue
    fi

    name_val="$(echo "$fm" | sed -n 's/^name: *//p')"
    desc_val="$(echo "$fm" | sed -n 's/^description: *//p')"
    tools_val="$(echo "$fm" | sed -n 's/^tools: *//p')"
    model_val="$(echo "$fm" | sed -n 's/^model: *//p')"

    stem="$(basename "$f" .md)"

    [ -z "$name_val" ] && fail "$f: name 필드 없음"
    [ -z "$desc_val" ] && fail "$f: description 필드 없음"
    [ -z "$tools_val" ] && fail "$f: tools 필드 없음"

    if [ -n "$name_val" ] && [ "$name_val" != "$stem" ]; then
        fail "$f: name(\"$name_val\")이 파일명(\"$stem\")과 다름"
    fi

    if [ -n "$model_val" ]; then
        case "$model_val" in
            haiku|sonnet|opus) ;;
            *) fail "$f: model 값 \"$model_val\"이 haiku|sonnet|opus 중 하나가 아님" ;;
        esac
    fi
done

# ── 2. skills/*/SKILL.md frontmatter ────────────────────────────
for d in skills/*/; do
    [ -d "$d" ] || continue
    f="${d}SKILL.md"
    dirname_val="$(basename "$d")"
    if [ ! -e "$f" ]; then
        fail "$d: SKILL.md 없음"
        continue
    fi
    fm="$(frontmatter "$f")"
    name_val="$(echo "$fm" | sed -n 's/^name: *//p')"
    desc_val="$(echo "$fm" | sed -n 's/^description: *//p')"

    [ -z "$name_val" ] && fail "$f: name 필드 없음"
    [ -z "$desc_val" ] && fail "$f: description 필드 없음"
    if [ -n "$name_val" ] && [ "$name_val" != "$dirname_val" ]; then
        fail "$f: name(\"$name_val\")이 폴더명(\"$dirname_val\")과 다름"
    fi
done

# ── 3. dangling local markdown 링크 ──────────────────────────────
# [text](path) 형태 중 http(s):// 아니고 앵커(#...)만도 아닌 상대경로 대상만 검사.
while IFS=: read -r src link; do
    [ -z "$link" ] && continue
    case "$link" in
        http://*|https://*|mailto:*) continue ;;
    esac
    target="${link%%#*}"
    [ -z "$target" ] && continue
    srcdir="$(dirname "$src")"
    if [ ! -e "$srcdir/$target" ] && [ ! -e "$target" ]; then
        fail "$src: dangling 링크 \"$link\" (대상 파일 없음)"
    fi
done < <(
    for f in agents/*.md skills/*/SKILL.md README.md; do
        [ -e "$f" ] || continue
        grep -oE '\]\([^)]+\)' "$f" | sed -E 's/^\]\((.*)\)$/\1/' | while read -r l; do
            echo "$f:$l"
        done
    done
)

# ── 4. 루트에 낯선 실행 가능 디렉터리 없는지(workflows/ 재발 방지) ──
allowed_dirs="agents skills .claude-plugin .cidd .claude .git .github scripts"
for d in */; do
    dname="$(basename "$d")"
    case " $allowed_dirs " in
        *" $dname "*) ;;
        *) fail "루트에 미승인 디렉터리 \"$dname\" — plugin에 스킬/에이전트 외 실행 가능 파일 번들 금지(workflows/ 충돌 사고 재발 위험)" ;;
    esac
done

# ── 결과 ─────────────────────────────────────────────────────────
if [ "$errors" -eq 0 ]; then
    echo "OK — 문제 없음"
    exit 0
else
    echo "FAIL — ${errors}건"
    exit 1
fi
