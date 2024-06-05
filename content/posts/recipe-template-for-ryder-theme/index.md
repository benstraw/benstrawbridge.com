+++
title = 'Recipe Template for Ryder Theme'
date = 2024-05-29T23:37:29-07:00
# draft = true
# summary = ""
categories = [""]
tags = [
  "Ryder Theme",
  "Recipe Schema",
  "Structured Data",
  "Hugo",
  "SEO"
  ]
# featured_image = ""
homeFeatureIcon = "fa-solid fa-burst"
# showTOC = true
+++

The recipe templates for The Ryder Theme for Hugo websites are progressing well. Today I released an update that creates the [schema.org json-ld specification tags for a recipe](https://schema.org/Recipe). This allows your recipe content to show up as "rich content" in search engines and social media platforms.

Using my favorite sample data recipe, [Tarragon Beets Salad]({{< relref "/projects/recipes/tarragon-beets-salad/" >}}), you can see the metadata laid out as it is seen by computers on this Google test tool. [Rich Results Test](https://search.google.com/test/rich-results/result?id=otdbKRI_M7PHdQRtKocn5g).

The warnings received are because there were no images defined for each HowToStep of the recipe. The entire recipe does have an image url; it uses the same image url that is used to generate the OG tags.

This update was helped greatly by [@idarek](https://discourse.gohugo.io/u/idarek/summary) on the [Hugo forums](https://discourse.gohugo.io/t/a-little-side-project-new-hugo-based-website-yummyrecipes-uk/38328) and his recipe website [Yummy Recipes UK - Nut-Free Cooking & Baking](https://yummyrecipes.uk/). I did modify the code posted on those forum pages to expand the schema to support HowToStep for each step of the recipe, instead of just posting the entire recipe in one HowToStep.

I did this by including a table in the Front matter of each page for each step and the data.

## Front matter

**Ingredients** is an actual taxonomy setup in `hugo.toml`, so that is just a summary of the main ingredients.  It then creates taxonomy pages for these main ingredients, so I can have summary pages of all the recipes using my favorite ingredients easily... like [Mushrooms]({{< relref "/ingredients/mushrooms/" >}})

**recipeIngredients** is the list of actual recipe ingredients with the units built into the string. There is the dream of separating units out but it is too complicated to do with Hugo on this first pass through.

Each `[[recipeInstruction]]` is essentially an array of tables to which you can add what is needed. I override name with a `**` which skips that row in the schema and outputs a header in the template.

{{< highlight toml >}}
ingredients = [
  "beets",
  "celery",
]
recipeIngredients = [
    "**FOR SALAD",
    "5 Beets",
    "½ heart of celery",
    ...
]
[[recipeInstructions]]
  name = "**For Beets (Can be done the day before)"
[[recipeInstructions]]
  name = "preheat"
  text = "Preheat oven to 425."
[[recipeInstructions]]
  name = "slice"
  text = "Cut (optionally peeled) beets into medium thin slices."
  ...
{{< /highlight >}}

## Shortcodes

Here are the shortcode which are included as part of the [Ryder Theme](https://github.com/arts-link/ryder) from [arts-link.com](https://www.arts-link.com/).

### recipe-ingredients-list.html
{{< highlight-github owner=arts-link repo=ryder path=layouts/shortcodes/recipe-ingredients-list.html showlink=false >}}

### recipe-howto-steps-list.html
{{< highlight-github owner=arts-link repo=ryder path=layouts/shortcodes/recipe-howto-steps-list.html showlink=false  >}}


## Test results

{{<figure src="test-results.png" id="test1" title="Test results from the google rich results tool.">}}

{{<figure src="screencapture-search-google-test-rich-results-result-r-recipes.png" title="Recipe details from the google rich results tool.">}}