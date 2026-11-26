# Gör om CookCLI:s JSON till en enkel struktur som Hugo-mallarna läser.
# Anropas från build-recipes.sh med --arg lang sv|en.
#
# Resultat:
#   { sections: [ { name, ingredients: [{name, amount, note}],
#                   content: [ {type: "step"|"tip", text} ] } ],
#     ingredients: ["8 dl vetemjöl", ...],      # för Schema.org
#     steps: ["Lös jästen ...", ...] }          # för Schema.org
#
# Ingredienser som börjar med & (t.ex. @&smör{}) är hänvisningar till en
# ingrediens som redan står i listan: de visas i stegen men inte i listan.

def num:
  if (. | floor) == . then (. | floor | tostring)
  else (. * 100 | round / 100 | tostring) | if $lang == "sv" then gsub("\\."; ",") else . end
  end;

def value:
  if . == null then ""
  elif .type == "number" then
    (.value) as $n
    | if $n.type == "regular" then ($n.value | num)
      elif $n.type == "fraction" then
        (($n.value.whole // 0) | if . == 0 then "" else (num + " ") end)
        + (($n.value.num | tostring) + "/" + ($n.value.den | tostring))
      else ($n.value | tostring) end
  elif .type == "range" then ((.value.start | value) + "–" + (.value.end | value))
  elif .type == "text" then .value
  else (.value | tostring) end;

def amount:
  if . == null then ""
  else [(.value | value), (.unit // "")] | map(select(. != "")) | join(" ")
  end;

def clean_name: sub("^&"; "");

# Talvärdet för en mängd som går att skala (för portionsväljaren), annars null.
def scalable_value:
  if . == null or (.scalable | not) or .value.type != "number" then null
  else .value.value as $n
    | if $n.type == "regular" then $n.value
      elif $n.type == "fraction" then (($n.value.whole // 0) + $n.value.num / $n.value.den)
      else null end
  end;

# "@&jäst" utan klamrar blir kvar som text i CookCLI; ta bort tecknen.
def clean_text: gsub("@&(?<w>[^\\s.,;:!?)]+)"; "\(.w)");

. as $r
| def item_text:
    if .type == "text" then (.value | clean_text)
    elif .type == "ingredient" then ($r.ingredients[.index].name | clean_name)
    elif .type == "cookware" then $r.cookware[.index].name
    elif .type == "timer" then ($r.timers[.index] | (.quantity | amount) as $q | if .name then .name + (if $q != "" then " (" + $q + ")" else "" end) else $q end)
    elif .type == "inlineQuantity" then ($r.inline_quantities[.index] | amount)
    else "" end;

  # Ett steg som bara består av ingredienser och kommatecken är en ingredienslista.
  def is_ingredient_list:
    (.items | any(.type == "ingredient"))
    and (.items | all(.type == "ingredient" or (.type == "text" and (.value | test("^[\\s,;]*$")))));

  def ingredient_entry:
    $r.ingredients[.index]
    | select(.name | startswith("&") | not)
    | {name: .name, amount: (.quantity | amount), note: (.note // ""),
       value: (.quantity | scalable_value), unit: (.quantity.unit // "")};

  [ $r.sections[]
    | {
        name: .name,
        ingredients: [ .content[] | select(.type == "step") | .value.items[] | select(.type == "ingredient") | ingredient_entry ],
        content: [ .content[]
                   | if .type == "text" then {type: "tip", text: (.value | clean_text)}
                     elif (.value | is_ingredient_list) then empty
                     else {type: "step", text: ([.value.items[] | item_text] | join("") | gsub("\\s+"; " ") | ltrimstr(" ") | rtrimstr(" "))}
                     end ]
      }
  ] as $sections
| {
    sections: $sections,
    ingredients: [ $sections[].ingredients[] | [.amount, .name] | map(select(. != "")) | join(" ") ],
    steps: [ $sections[].content[] | select(.type == "step") | .text ]
  }
