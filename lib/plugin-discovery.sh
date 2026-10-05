#!/usr/bin/env bash
# Match PluginRegistry.rescan's raw third-party glob, before ID deduplication.
# Directory symlinks are discoverable; hidden staging directories are not.
sea_raw_candidates() {
  local dir=$1 sub
  for sub in "$dir"/*/; do
    [[ -f $sub/manifest.json ]] || continue
    jq -c --arg path "${sub%/}" '
      # jq dtoa mode 0 supplies shortest nearest/ties-even digits, but uses
      # different notation. Decnum builds also reduce input to 17 decimal
      # digits before binary64 conversion; correct that possible double
      # rounding against exact dyadic midpoints while the literal is intact.
      def number_identity:
        def decimal_step($factor; $carry):
          reduce (explode | reverse[]) as $digit
            ({digits:[], carry:$carry};
             ($factor * ($digit - 48) + .carry) as $value |
             .digits += [48 + (($value % 10 + 10) % 10)] |
             .carry = ($value / 10 | floor)) |
          # Carry may have many digits when multiplying by a power block.
          # A negative initial offset borrows through the input digits; only
          # the remaining positive carry belongs at the front.
          until(.carry <= 0;
            .digits += [48 + (.carry % 10)] |
            .carry = (.carry / 10 | floor)) |
          .digits | reverse | implode;
        def midpoint($mantissa; $factor; $offset; $exponent):
          ($mantissa | tostring | decimal_step($factor; $offset)) as $coefficient |
          # For F <= 5^20, carry <= F-1, so digit*F+carry <=
          # 10*F-1 = 953674316406249 < 2^50 (and hence < 2^53).
          # All integer products/sums are exact. Dividing by 10 gives a
          # quotient below 2^47: rounding error is at most 1/128, less than
          # the 0.1 distance of any nonintegral quotient from an integer.
          # Integral quotients are representable, so floor is exact too.
          # Initial offsets are only 0 or -1; dividing -1 by 10 also floors
          # correctly, retaining the borrow until a nonzero digit.
          (if $exponent < 0 then {single:5, block:95367431640625}
           else {single:2, block:1048576} end) as $power |
          ($exponent | fabs) as $steps |
          (reduce range(0; ($steps / 20 | floor)) as $unused
            ($coefficient; decimal_step($power.block; 0))) |
          (reduce range(0; $steps % 20) as $unused
            (.; decimal_step($power.single; 0))) |
          (. + (if $exponent < 0 then "e" + ($exponent | tostring) else "" end) |
           fromjson);
        def binary64:
          # Older/non-decnum jq parses directly to binary64. Detect literal
          # preservation without requiring the newer have_decnum builtin.
          if 100000000000000000001 == 100000000000000000000 then . + 0
          else
            (if . < 0 then -1 else 1 end) as $sign |
            (if $sign < 0 then tostring | ltrimstr("-") | fromjson else . end) as $raw |
            ($raw + 0) as $rounded |
            # IEEE overflow boundary is (2^54-1)*2^970; at the tie,
            # round-to-even selects the conceptual 2^1024 (Infinity).
            if ($raw | tostring | sub("[eE].*$"; "") | gsub("[-.]"; "") |
                sub("^0+"; "") | sub("0+$"; "") | length) <= 17
            then $sign * $rounded
            elif $rounded | isinfinite then
              if $raw < midpoint(9007199254740992; 2; -1; 970)
              then $sign * 1.7976931348623157e308
              else $sign * $rounded end
            elif $rounded == 0 then
              if $raw > midpoint(1; 1; 0; -1075)
              then $sign * 5e-324 else 0 end
            else
              ($rounded | frexp | .[1]) as $exponent |
              ([($exponent - 53), -1074] | max) as $unit |
              ldexp($rounded; -$unit) as $mantissa |
              midpoint($mantissa; 2; 1; $unit - 1) as $upper |
              (if $mantissa == 4503599627370496 and $unit > -1074
               then midpoint($mantissa; 4; -1; $unit - 2)
               else midpoint($mantissa; 2; -1; $unit - 1) end) as $lower |
              ($mantissa % 2 == 1) as $odd |
              $sign * (
                if $raw > $upper or ($raw == $upper and $odd)
                then nextafter($rounded; infinite)
                elif $raw < $lower or ($raw == $lower and $odd)
                then nextafter($rounded; 0)
                else $rounded end)
            end
          end;
        binary64 |
        if . == 0 then "0"
        elif isinfinite then if . < 0 then "-Infinity" else "Infinity" end
        else
          tostring |
          capture("^(?<sign>-?)(?<whole>[0-9]+)(?:\\.(?<fraction>[0-9]+))?(?:[eE](?<exponent>[+-]?[0-9]+))?$") |
          .sign as $sign |
          (.whole + (.fraction // "")) as $raw |
          ($raw | match("^0*").length) as $leading |
          ($raw[$leading:] | sub("0+$"; "")) as $digits |
          (.whole | length) + ((.exponent // "0") | tonumber) - $leading as $position |
          ($digits | length) as $length |
          $sign + (
            if $position > 0 and $position <= 21 then
              if $position >= $length then $digits + ("0" * ($position - $length))
              else $digits[:$position] + "." + $digits[$position:] end
            elif $position > -6 and $position <= 0 then
              "0." + ("0" * (-$position)) + $digits
            else
              $digits[:1] + (if $length > 1 then "." + $digits[1:] else "" end) +
              "e" + (if $position > 0 then "+" else "" end) + (($position - 1) | tostring)
            end)
        end;
      # Registry validation indexes by JavaScript String(id). Accepted action
      # IDs contain no commas/spaces, so only singleton arrays can match.
      def identity:
        if type=="array" then
          if length==1 then .[0] | identity else "" end
        elif type=="object" then ""
        elif type=="null" then "null"
        elif type=="boolean" then tostring
        elif type=="number" then number_identity
        else . end;
      select(type=="object" and has("id")) |
      {id:(.id | identity), sourceDir:$path}
    ' "$sub/manifest.json" 2>/dev/null || true
  done
}
sea_candidates_for_id() {
  local dir=$1 id=$2
  sea_raw_candidates "$dir" | jq -c --arg id "$id" '
    select(.id==$id)
  '
}
sea_unique_candidates() {
  local id=$1 expected=$2
  jq -se --arg id "$id" --arg path "$expected" '
    map(select(.id==$id)) |
    length==1 and .[0].sourceDir==$path
  ' >/dev/null
}
sea_unique_source() {
  local dir=$1 id=$2 expected=$3
  sea_raw_candidates "$dir" | sea_unique_candidates "$id" "$expected"
}
