#!/usr/bin/env bash
#
# install-skills.sh - macOS / Linux counterpart of Install-Skills.ps1.
#
# Bob discovers a skill by the FOLDER NAME it sits under, not by the `name:` in the SKILL.md
# frontmatter. It reads, in this order:
#
#     <workspace folder>/.bob/skills/<name>/SKILL.md      (workspace scope)
#     <workspace folder>/.claude/skills/<name>/SKILL.md
#     ~/.bob/skills/<name>/SKILL.md                       (global scope)
#     ~/.agents/skills/<name>/SKILL.md
#     ~/.claude/skills/<name>/SKILL.md
#
# Workspace scope is one VS Code *workspace folder*, not the .code-workspace file: a task is
# bound to a single folder, so only that folder's .bob/skills is in scope. Global scope is
# the same everywhere, which is why it is the default here.
#
# Validation comes first and is a hard gate: folder name, SKILL.md `name:` and .bobmodes
# `slug:` must be the same string, and it must be a valid Bob skill name (kebab-case, max 64
# characters). Bob drops an invalid name in silence, so a folder called flow_builder never
# loads and never says why. If any skill disagrees, nothing is installed.
#
# Usage:
#   ./scripts/install-skills.sh --dry-run              # preview, changes nothing
#   ./scripts/install-skills.sh                        # symlink into ~/.bob/skills
#   ./scripts/install-skills.sh --agent both --prune   # ~/.bob and ~/.claude, drop leftovers
#   ./scripts/install-skills.sh --project ~/dev/myapp --name ace-review
#                                                      # copy one skill into a project

set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
skill_roots="ace_modes general_modes"

agent="bob"
project=""
method=""
prune=0
dry_run=0
wanted=""

usage() {
    sed -n '3,28p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --agent)   agent="$2"; shift 2 ;;
        --project) project="$2"; shift 2 ;;
        --method)  method="$2"; shift 2 ;;
        --name)    wanted="$wanted $2"; shift 2 ;;
        --prune)   prune=1; shift ;;
        --dry-run) dry_run=1; shift ;;
        -h|--help) usage 0 ;;
        *) echo "Unknown option: $1" >&2; usage 1 ;;
    esac
done

case "$agent" in bob|claude|both) ;; *) echo "--agent must be bob, claude or both" >&2; exit 1 ;; esac

# Defaults differ by scope: a global install links (edits here stay live), a project install
# copies (the result is standalone and can be committed).
if [ -z "$method" ]; then
    if [ -n "$project" ]; then method="copy"; else method="link"; fi
fi
case "$method" in link|copy) ;; *) echo "--method must be link or copy" >&2; exit 1 ;; esac

frontmatter_name() {
    awk 'NR<=20 && /^name:[[:space:]]*/ { sub(/^name:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

bobmodes_slug() {
    awk 'NR<=40 && /^[[:space:]]*-?[[:space:]]*slug:[[:space:]]*/ { sub(/^[^:]*:[[:space:]]*/, ""); sub(/[[:space:]]+$/, ""); print; exit }' "$1"
}

# --- Phase 1: discover and validate -----------------------------------------

problems=""
all_names=""
mode_only=""

for root in $skill_roots; do
    [ -d "$repo_root/$root" ] || continue

    while IFS= read -r bobmodes; do
        dir="$(dirname "$bobmodes")"
        [ -f "$dir/SKILL.md" ] && continue
        mode_only="$mode_only ${dir#$repo_root/}"
    done < <(find "$repo_root/$root" -name '.bobmodes' -type f)

    while IFS= read -r skill_md; do
        dir="$(dirname "$skill_md")"
        folder="$(basename "$dir")"
        declared="$(frontmatter_name "$skill_md")"

        if [ -z "$declared" ]; then
            problems="$problems\n  $folder : SKILL.md has no 'name:' in its frontmatter"
        elif [ "$declared" != "$folder" ]; then
            problems="$problems\n  $folder : folder name vs SKILL.md name: '$declared'"
        fi

        if [ -f "$dir/.bobmodes" ]; then
            slug="$(bobmodes_slug "$dir/.bobmodes")"
            if [ -n "$slug" ] && [ "$slug" != "$folder" ]; then
                problems="$problems\n  $folder : folder name vs .bobmodes slug: '$slug'"
            fi
        fi

        if ! printf '%s' "$folder" | grep -Eq '^[a-z0-9]+(-[a-z0-9]+)*$'; then
            problems="$problems\n  $folder : not a valid skill name - kebab-case, lower-case letters and digits only (Bob drops it in silence)"
        elif [ "${#folder}" -gt 64 ]; then
            problems="$problems\n  $folder : name is longer than 64 characters"
        fi

        case " $all_names " in
            *" $folder "*) problems="$problems\n  $folder : duplicate skill name" ;;
            *) all_names="$all_names $folder"
               eval "src_${folder//-/_}=\"\$dir\"" ;;
        esac
    done < <(find "$repo_root/$root" -name 'SKILL.md' -type f)
done

if [ -n "$problems" ]; then
    printf '\nName drift detected - nothing was installed:%b\n\n' "$problems" >&2
    echo 'Folder name, SKILL.md name: and .bobmodes slug: must be identical and kebab-case.' >&2
    exit 1
fi

count=$(printf '%s' "$all_names" | wc -w | tr -d ' ')
[ "$count" -gt 0 ] || { echo "No skills found." >&2; exit 1; }
echo "Validated $count skills - folder name, frontmatter name and slug agree."
if [ -n "$mode_only" ]; then echo "Bob-mode only, no SKILL.md (import those as modes):$mode_only"; fi

install_names="$all_names"
if [ -n "$wanted" ]; then
    install_names=""
    for n in $wanted; do
        case " $all_names " in
            *" $n "*) install_names="$install_names $n" ;;
            *) echo "Unknown skill name: $n" >&2; echo "Available:$all_names" >&2; exit 1 ;;
        esac
    done
    echo "Installing:$install_names"
fi

# --- Destinations -----------------------------------------------------------

agent_dirs=""
if [ -n "$project" ]; then
    [ -d "$project" ] || { echo "Project path not found: $project" >&2; exit 1; }
    project="$(cd "$project" && pwd)"
    scope="project ($project)"
    if [ "$agent" != "claude" ]; then agent_dirs="$agent_dirs $project/.bob"; fi
    if [ "$agent" != "bob" ]; then agent_dirs="$agent_dirs $project/.claude"; fi
else
    scope="global"
    if [ "$agent" != "claude" ]; then agent_dirs="$agent_dirs $HOME/.bob"; fi
    if [ "$agent" != "bob" ]; then agent_dirs="$agent_dirs $HOME/.claude"; fi
fi

echo "Scope: $scope   Method: $method"

# A blanket ".bob/" line in a project's .gitignore also lands in the exclude list Bob builds
# for its own file search, so project skills can go unseen on the initial scan.
if [ -n "$project" ] && [ -f "$project/.gitignore" ]; then
    if grep -Eq '^\.(bob|claude)/?$' "$project/.gitignore"; then
        echo
        echo "Warning: $project/.gitignore ignores .bob or .claude wholesale."
        echo "  Bob derives its file-search excludes from .gitignore, so skills under that"
        echo "  directory can be missed on the initial scan. Ignore the noisy subfolders"
        echo "  instead (.bob/tasks/, .bob/.bob-errors/) and keep .bob/skills/ visible."
    fi
fi

run() {
    if [ "$dry_run" = "1" ]; then echo "  would: $*"; else "$@"; fi
}

# --- Phase 2: apply ---------------------------------------------------------
# Foreign entries are never touched, and a real directory that shadows one of our skills is
# moved to skills-backup rather than deleted.

exit_code=0

for agent_dir in $agent_dirs; do
    skills_dir="$agent_dir/skills"
    backup_dir="$agent_dir/skills-backup"
    echo
    echo "=== $skills_dir ==="
    [ -d "$skills_dir" ] || run mkdir -p "$skills_dir"

    for name in $install_names; do
        eval "src=\$src_${name//-/_}"
        link="$skills_dir/$name"

        if [ -L "$link" ]; then
            target="$(readlink "$link")"
            case "$target" in
                "$repo_root"/*)
                    if [ "$method" = "link" ] && [ "$target" = "$src" ]; then
                        echo "  $name: unchanged"
                        continue
                    fi
                    run rm -f "$link" ;;
                *)
                    echo "  $name: skipped - link points outside this repository -> $target"
                    exit_code=1
                    continue ;;
            esac
        elif [ -d "$link" ]; then
            its_name=""
            if [ -f "$link/SKILL.md" ]; then its_name="$(frontmatter_name "$link/SKILL.md")"; fi
            case " $all_names " in
                *" ${its_name:-__none__} "*)
                    if [ "$method" = "copy" ]; then
                        run rm -rf "$link"
                    else
                        run mkdir -p "$backup_dir"
                        run mv "$link" "$backup_dir/$name-$(date +%Y%m%d-%H%M%S)"
                    fi ;;
                *)
                    echo "  $name: skipped - real directory, not one of ours"
                    exit_code=1
                    continue ;;
            esac
        fi

        if [ "$method" = "link" ]; then
            run ln -s "$src" "$link"
            if [ "$dry_run" != "1" ]; then echo "  $name: linked -> $src"; fi
        else
            run mkdir -p "$link"
            run cp -R "$src/." "$link/"
            # Never ship these into someone else's tree: they hold real customer or personal
            # detail. Gitignored here, but a local working copy still has them on disk.
            if [ "$dry_run" != "1" ]; then
                find "$link" \( -name '.env' -o -name 'customer_profile.md' \) -delete 2>/dev/null || true
                find "$link" -type d -name 'log' -exec rm -rf {} + 2>/dev/null || true
            fi
            if [ "$dry_run" != "1" ]; then echo "  $name: copied from $src"; fi
        fi
    done

    # Leftovers from a rename: a symlink into this repository under a name that no longer
    # exists. Compared against every skill in the repository, not just the ones this run was
    # asked to install, so --name and --prune are safe together. Copies are never pruned -
    # a copy is indistinguishable from a hand-installed skill.
    for entry in "$skills_dir"/*; do
        [ -L "$entry" ] || continue
        name="$(basename "$entry")"
        case " $all_names " in *" $name "*) continue ;; esac
        target="$(readlink "$entry")"
        case "$target" in
            "$repo_root"/*)
                if [ "$prune" = "1" ]; then
                    run rm -f "$entry"
                    echo "  $name: pruned stale link -> $target"
                else
                    echo "  $name: stale link -> $target (re-run with --prune to remove)"
                fi ;;
        esac
    done
done

echo
echo 'Bob watches these directories and picks changes up without a restart; if a new skill'
echo 'does not show up under Settings > Skills, reload the window (Developer: Reload Window).'
echo 'Claude Code enumerates skills at session start - start a new session there.'
if [ -n "$project" ]; then
    echo
    echo 'Project-scope skills only apply to tasks running in THAT folder, and only when the'
    echo 'workspace is trusted. In a multi-root workspace, New Task asks which folder you are in.'
fi

exit $exit_code
