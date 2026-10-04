def str: if type == "string" then . else "" end;
def safeid: type == "string" and test("^[A-Za-z0-9][A-Za-z0-9._-]*$") and (contains("..")|not);
def repo: str | if test("^https://github\\.com/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(?:\\.git)?/?$") and (contains("..")|not) then rtrimstr("/") else "" end;
def sha: if type == "string" then test("^[0-9a-f]{40}$") else false end;
def preview: str | if (contains("..")|not) and test("^(?:https://plugins\\.omarchy\\.org/)?assets/img/plugins/[A-Za-z0-9._-]+\\.webp$") then if startswith("https://") then . else "https://plugins.omarchy.org/" + . end else "" end;
def snapshotRefusal($repo):
  if ((.status|type)!="string" and .status!=null) then "Catalog status has an invalid type; installation is unavailable until upstream corrects it."
  elif $repo=="" then "Source is unavailable or unsupported; inspect upstream manually."
  elif (.id|startswith("omarchy.")) then "Reserved platform plugins cannot be installed from the community catalog."
  elif ((.status|str)|ascii_downcase|test("yanked|quarantined|unavailable")) then "This catalog listing is blocked or unavailable."
  elif .installAvailable!=true then (.installNote|str) as $note | if $note!="" then $note else "The catalog does not offer installation for this listing." end
  elif .repositoryLayout!="root-plugin" or .manifestPath!="manifest.json" then "Only root-plugin repositories with a root manifest.json support immutable installation."
  elif (.listingValidatedCommit|sha|not) then "The catalog has no valid full immutable listing revision."
  elif .verificationSnapshotStatus!="verified" then "The listing snapshot is not verified; installation is unavailable."
  elif (.verificationCommit|sha|not) or .verificationCommit!=.listingValidatedCommit then "Snapshot verification does not match the immutable listing revision."
  else "" end;
if type != "object" or (.plugins|type) != "array" or (.plugins|length) == 0 then error("Catalog must contain a nonempty plugins array") else . end
| .plugins as $plugins
| if any($plugins[]; type != "object" or (.id|safeid|not) or (.name|type) != "string" or (.name|length)==0) then error("Catalog contains malformed entries") else . end
| if ([$plugins[].id]|unique|length) != ($plugins|length) then error("Catalog has duplicate IDs") else . end
| {schemaVersion:1, ok:true, source:$source, fetchedAt:$now, generatedAt:(.generatedAt|str), stale:false,error:"",plugins:[$plugins[] |
  (.repo|repo) as $repo |
  snapshotRefusal($repo) as $refusal |
  {id,name,description:(.description|str),author:(.author|str),version:(.version|str),category:(.category|str),tags:((.tags//[])|if type=="array" then map(select(type=="string")) else [] end),repo:$repo,previewImage:(.previewImage|preview),previewThumbnail:(.previewThumbnail|preview),installAvailable:($refusal==""),installNote:(if $refusal!="" then $refusal else "Install exactly the verified listing revision, detached and initially disabled; enabling requires a fresh snapshot/content check." end),verificationStatus:(.verificationStatus|str),verificationCoverage:(.verificationCoverage|str),verificationSnapshotStatus:(.verificationSnapshotStatus|str),verificationCommit:(.verificationCommit|str),listingValidatedCommit:(.listingValidatedCommit|str),upstreamObservedCommit:(.upstreamObservedCommit|str),upstreamCheckStatus:(.upstreamCheckStatus|str),stars:(.stars|if type=="number" then . else 0 end),listedAt:(.listedAt|str),status:(.status|str),sourceType:(.sourceType|str),repositoryLayout:(.repositoryLayout|str),manifestPath:(.manifestPath|str),license:(.license|str)}]}
