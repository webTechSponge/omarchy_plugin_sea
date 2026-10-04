# Shared, fail-closed Git observation. No inherited configuration or credentials.
sea_git() {
  local index_env=()
  [[ -z ${sea_index:-} ]] || index_env=("GIT_INDEX_FILE=$sea_index")
  timeout --kill-after=5 120 env -i PATH="$PATH" HOME=/nonexistent LC_ALL=C "${index_env[@]}" \
    GIT_CONFIG_NOSYSTEM=1 GIT_CONFIG_GLOBAL=/dev/null GIT_TERMINAL_PROMPT=0 \
    GIT_NO_REPLACE_OBJECTS=1 git -c core.hooksPath=/dev/null \
    -c protocol.allow=never -c protocol.https.allow=always -c protocol.file.allow=never \
    -c core.fsmonitor=false -c core.untrackedCache=false -c core.filemode=true \
    -c core.ignoreStat=false -c core.trustctime=true "$@"
}
sea_valid_url() { [[ $1 =~ ^https://github\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ && $1 != *..* ]]; }
# All existing components must be real directories owned by this user or root,
# and not writable by another user. Root-owned sticky /tmp is permitted.
sea_safe_path() {
  local target=$1 part current='' mode owner
  local -a parts
  [[ $target == /* && $target != *'/../'* && $target != */.. && $target != *'/./'* ]] || return 1
  IFS=/ read -r -a parts <<<"$target"
  for part in "${parts[@]}"; do
    [[ -n $part ]] || continue
    current+=/$part
    [[ ! -L $current ]] || return 1
    [[ -e $current ]] || continue
    [[ -d $current ]] || return 1
    owner=$(stat -c %u -- "$current") || return 1
    mode=$(stat -c %a -- "$current") || return 1
    [[ $owner == "$UID" || $owner == 0 ]] || return 1
    (( (8#$mode & 0022) == 0 )) || [[ $owner == 0 && $mode == 1777 ]] || return 1
  done
}
sea_git_safe() {
  local path=$1 record key value links
  sea_safe_path "$path/.git" && [[ -O $path && -O $path/.git && -d $path/.git && ! -L $path/.git && -f $path/.git/config && ! -L $path/.git/config && -O $path/.git/config ]] || return 1
  links=$(timeout 15 find "$path/.git" -type l -print -quit) || return 1
  [[ -z $links && ! -e $path/.git/objects/info/alternates && ! -e $path/.git/info/grafts && ! -e $path/.git/commondir ]] || return 1
  # Read config without includes; refuse every potentially executable or
  # content-changing option rather than trying to enumerate filter names.
  while IFS= read -r -d '' record; do
    [[ $record == *$'\n'* ]] || return 1
    key=${record%%$'\n'*}; value=${record#*$'\n'}
    [[ $value != *$'\n'* ]] || return 1
    case $key in
      core.repositoryformatversion) [[ $value == 0 ]] || return 1 ;;
      core.bare) [[ $value == false ]] || return 1 ;;
      core.filemode|core.logallrefupdates|core.ignorecase|core.precomposeunicode) [[ $value == true || $value == false ]] || return 1 ;;
      remote.origin.url) sea_valid_url "$value" || return 1 ;;
      remote.origin.fetch) [[ $value == '+refs/heads/*:refs/remotes/origin/*' ]] || return 1 ;;
      *) return 1 ;;
    esac
  done < <(sea_git config --file "$path/.git/config" --no-includes --null --list)
  sea_git config --file "$path/.git/config" --no-includes --list >/dev/null || return 1
}
# Globals are initialized on every observation; failure never supplies authority.
sea_observe() {
  local path=$1 status index_dir types record meta file mode kind object actual permissions
  sea_head='' sea_repo='' sea_detached=false sea_clean=false
  sea_git_safe "$path" || return 1
  sea_repo=$(sea_git config --file "$path/.git/config" --no-includes --get-all remote.origin.url) || return 1
  sea_valid_url "$sea_repo" || return 1
  sea_head=$(sea_git -C "$path" rev-parse --verify HEAD^{commit}) || return 1
  [[ $sea_head =~ ^[0-9a-f]{40}$ ]] || return 1
  if ! sea_git -C "$path" symbolic-ref -q HEAD >/dev/null; then sea_detached=true; fi
  types=$(sea_git -C "$path" ls-tree -r "$sea_head") || return 1
  [[ ! $types =~ (^|$'\n')160000 && ! -e $path/.gitmodules ]] || return 1
  # Never trust stat cache or flags in an externally managed working index.
  index_dir=$(mktemp -d) || return 1
  sea_index=$index_dir/index
  if sea_git -C "$path" read-tree "$sea_head" &&
      status=$(sea_git -C "$path" status --porcelain=v1 --untracked-files=all --ignored) &&
      [[ -z $status ]] &&
      sea_git -C "$path" diff --quiet --no-ext-diff --no-textconv "$sea_head" -- &&
      sea_git -C "$path" ls-tree -rz "$sea_head" >"$index_dir/tree"; then
    sea_clean=true
    # Compare literal file bytes too: .gitattributes and Git's private
    # info/attributes must not normalize a changed executable back to a blob.
    while IFS= read -r -d '' record; do
      meta=${record%%$'\t'*}; file=${record#*$'\t'}
      read -r mode kind object <<<"$meta"
      if [[ $kind != blob || ( $mode != 100644 && $mode != 100755 ) ||
          ! -f $path/$file || -L $path/$file ]]; then
        sea_clean=false; break
      fi
      permissions=$(stat -c %a -- "$path/$file") || { sea_clean=false; break; }
      if [[ ! -O $path/$file ]] || (( (8#$permissions & 0022) != 0 )); then
        sea_clean=false; break
      fi
      actual=$(sea_git -C "$path" hash-object --no-filters -- "$path/$file") || { sea_clean=false; break; }
      [[ $actual == "$object" ]] || { sea_clean=false; break; }
    done <"$index_dir/tree"
  fi
  unset sea_index
  rm -rf -- "$index_dir"
}
sea_verify() {
  local path=$1 expected_id=$2 expected_repo=$3 expected_sha=$4
  [[ -f $path/manifest.json && ! -L $path/manifest.json ]] || return 1
  sea_observe "$path" || return 1
  [[ $sea_repo == "$expected_repo" && $sea_head == "$expected_sha" && $sea_detached == true && $sea_clean == true ]] || return 1
  sea_git -C "$path" fsck --full --no-reflogs "$expected_sha" >/dev/null || return 1
  jq -e --arg id "$expected_id" '.id==$id' "$path/manifest.json" >/dev/null || return 1
}
