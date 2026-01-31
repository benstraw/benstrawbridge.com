+++
title = 'Home Feed Filtering and Colorization'
date = 2024-06-10T20:41:19-07:00
# draft = true
# summary = ""
# categories = [""]
# hideAsideBar = true
tags = [
  "hugo",
  "ryder-theme",
  "filtering",
  "feed"
]
# featured_image = ""
homeFeatureIcon = "fa-solid fa-house"
# showTOC = true
+++

## Limit your home page feed by Section, Category or Tag

You can now set params in your `hugo.toml` file to keep any pesky pages off your homepage that you may not wish to promote for whatever reason.

<!--more-->

{{< highlight go-html-template >}}
  # homepage list exclusion... 
  excludedSections = ["fineprint", "portfolio", "goals"]
  excludedCategories = ["catalog","recipes"]
  excludedTags = ["excluded"]
{{< /highlight >}}

### How does it work?

> {{< font-awesome "text-neutral-900 dark:text-neutral-100 fa-solid fa-wand-magic-sparkles" >}} Magic 

Here is how my `home.html` page loop works to deal with these exclusions.

{{< highlight go-html-template >}}
<div class="lg:grid-cols-2  p-4 mx-auto grid grid-cols-1 gap-12  mb-5">
    <h2 class="lg:col-span-2 flex p-3 items-center mb-2 text-3xl uppercase">Latest stuff</h2>
      
    {{ $excludedSections := site.Params.excludedSections | default slice }}
    {{ $excludedCategories := site.Params.excludedCategories | default slice }}
    {{ $excludedTags := site.Params.excludedTags | default slice }}
    {{- $filteredPages := slice -}}
    {{- range $pages.ByLastmod.Reverse }}
      {{- $excludePage := false -}}
      {{- range .Params.categories }}
        {{- if in $excludedCategories . }}
          {{- $excludePage = true -}}
          {{- break -}}
        {{- end }}
      {{- end }}
      {{- range .Params.tags }}
        {{- if in $excludedTags . }}
          {{- $excludePage = true -}}
          {{- break -}}
        {{- end }}
      {{- end }}
      {{- if $excludePage }}
        {{- continue -}}
      {{- end }}
      
      {{- if in $excludedSections .Section }}
        {{- continue }}
      {{- end }}
      {{- if eq .Summary "" }}
        {{- continue }}
      {{- end }}
      {{- $filteredPages = $filteredPages | append . -}}
    {{- end }}

    {{ range (.Paginate $filteredPages 18).Pages }}
    {{/*  {{- range $filteredPages.Limit 18 }}  */}}
      {{- partial "card-category-color.html" . }}
    {{- end }}
    {{ template "_internal/pagination.html" . }}
  </div>
{{< /highlight >}}

## Express yourself with colorful cards

There is a new default partial called `card-category-color.html` and it is the new layout for all lists in the site. In addition you can control your colors all through the front matter or configuration.

You set your base default color / gradient using tailwindcss classes in `hugo.toml`, then you can override that color on a per section or per category basis. For instance on this exampleSite, no base color has been set in the `hugo.toml` file, so it falls back on the hardcoded default of a gray gradient.

{{< highlight go-html-temlplate >}}
{{ $headerStyle := default "bg-gradient-to-r from-zinc-400 to-zinc-300" (.Param "cardCategoryColorsDefault") }}
{{< /highlight >}}

For further color configuration look to the default pages you can create for categories and sections by creating that `_index.md` file and adding some param for it -- like so. Putting it in the cascade ensures all it's children receive the gift.

{{< highlight go-html-temlplate >}}
[cascade]
  sectionTitle = "Maps on BenStrawbridge.com"
  cardCategoryColorsDefault = "bg-gradient-to-r from-red-500 to-orange-500"
{{< /highlight >}}