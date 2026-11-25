# Receptsamling

En statisk, flerspråkig receptsajt som byggs från vanliga textfiler och publiceras automatiskt på GitHub Pages.

- Recept skrivs i [Cooklang](https://cooklang.org/docs/spec/) (`.cook`), övrig text i Markdown.
- Svenska är huvudspråk, engelska ett tillägg. Alla recept behöver inte finnas på båda språken.
- Sajten byggs med [Hugo](https://gohugo.io), recepten tolkas med [CookCLI](https://github.com/cooklang/cookcli) och sökningen görs av [Pagefind](https://pagefind.app).

## Skriva innehåll

Allt du skriver ligger under `innehall/`, uppdelat per språk:

```
innehall/
  sv/
    _index.md                startsidans text
    forord.md, om.md         fristående sidor
    recept/
      01-brod-och-bakat/     ett kapitel (siffran styr ordningen)
        _index.md            kapitelinledning
        Kanelbullar.cook     receptet
        Kanelbullar.md       kort historia (valfri)
        Kanelbullar.jpg      bild (valfri)
    blogg/
      2026-12-julbak.md
    restauranger/operakallaren/_index.md   egen text för en restaurang (valfri)
  en/
    (samma struktur, bara det som är översatt)
```

### Recept

```
---
title: Kanelbullar
id: kanelbullar
description: Klassiska bullar med kardemumma i degen.
servings: 30 bullar
time: 3 timmar
tags: [bakning, fika, jul]
kategori: [Bakverk]
restaurang: [Operakällaren]
forfattare: [Mormor Greta]
date: 2026-11-25
---
= Deg
@vetemjöl{8%dl}, @socker{1%dl}, @smör{100%g}(smält)

= Gör så här
Smält @&smör i en #kastrull{} och låt svalna i ~{10%minutes}.
> Mormors tips: dubbel sats, frys hälften.
```

- `title` och `id` är obligatoriska. `id` är receptets fasta namn och är **samma i alla språk**.
- Första stycket i ett avsnitt listar ingredienserna; stegen refererar till dem med `@&`.
- `= Rubrik` delar receptet i avsnitt med egna ingredienslistor.
- Rader som börjar med `>` visas som tips.
- Bild och kort historia har samma filnamn som receptet. Bilder läggs bara i den svenska mappen; den engelska versionen hittar bilden via `id`.

### Översättningar

Ett engelskt recept kopplas till det svenska genom samma `id` – filnamn och titel får skilja sig (`Kanelbullar.cook` och `Cinnamon buns.cook`). Artiklar, kapitel och sidor kopplas ihop genom att ha **samma filnamn och mapp** i `sv/` och `en/`.

Kategorier översätts med ordlistan längst ned i `i18n/en.toml`:

```toml
"kategori:Förrätt" = "Starter"
```

### Bloggartiklar

```
---
title: Julbak hemma hos mormor
date: 2026-12-01
recept: [kanelbullar, lussekatter]
image: julbak.jpg
---
Det började alltid med {{< recept kanelbullar >}}.
```

`recept:` ger receptkort längst ned i artikeln och en "Läs mer"-länk på receptet. `{{< recept id >}}` länkar till receptet på rätt språk.

### Etiketter

`tags`, `restaurang`, `forfattare` och `kategori` får egna sidor (`/sv/restauranger/operakallaren/` osv.). Fler sorter läggs till i `hugo.toml` under `[taxonomies]`, `params.etiketter` och `permalinks`.

## Bygga lokalt

Du behöver:

- [Hugo extended](https://gohugo.io/installation/) 0.152 eller senare
- [CookCLI](https://cooklang.org/cli/download/) (`cook`)
- `jq`
- Node.js (bara för sökningen, valfritt lokalt)

```sh
./scripts/dev.sh
```

Skriptet gör om recepten, startar en förhandsvisning på <http://localhost:1313/> och bygger om när du sparar en fil. Sökrutan fungerar bara i ett fullständigt bygge (`./scripts/dev.sh --build`).

## Publicering

Varje ändring på `main` byggs och publiceras av `.github/workflows/deploy.yml`:

1. CookCLI installeras i en låst version.
2. `scripts/build-recipes.sh` gör om varje `.cook`-fil till en sida i `.build/` och kontrollerar `id`, översättningar och receptlänkar.
3. Hugo bygger sajten.
4. Pagefind bygger sökindexet.
5. Resultatet publiceras på GitHub Pages.

Första gången: gå till repots **Settings → Pages** och välj **Source: GitHub Actions**.

Om ett recept innehåller fel stannar bygget och säger vilken fil det gäller. Den publicerade sajten ligger kvar oförändrad.

## Mappar för mallen

| Mapp | Innehåll |
| --- | --- |
| `layouts/` | Hugo-mallar (HTML) |
| `assets/` | CSS och JavaScript |
| `i18n/` | knapp- och menytexter per språk, kategoriordlista |
| `scripts/` | byggskript |
| `.build/` | genererat, checkas inte in |
