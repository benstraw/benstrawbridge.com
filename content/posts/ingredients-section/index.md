+++
title = 'Ingredients Section'
date = 2024-06-05T00:11:09-07:00
# draft = true
# summary = ""
# categories = [""]
tags = [
  "Hugo",
  "Recipe Template",
  "Taxonomy",
  "Ingredients",
  "Content Management",
  "Recipe Schema"
]
# featured_image = ""
# showTOC = true
+++

> Check out the new [Ingredients Taxonomy pages]({{< relref "/ingredients" >}})

## Using Taxonomy effectively

As part of the recipe template configuration being developed for The Ryder Theme for Hugo websites, a new taxonomy is created for ingredients. Ingredients are not the same as recipeIngredients; they are defined as an array in the front matter. I didn’t want a taxonomy page generated for every single recipe ingredient, so I created a separate variable. The recipeIngredients are used to display the ingredients on the page and for the recipe schema, ensuring the pages are properly displayed as recipe rich results in Google and other search engines.

<!--more-->

From my regular sample data recipe of [Tarragon Beets Salad]({{< relref "/projects/recipes/tarragon-beets-salad" >}}), you can see how they are different. One is for general items, and the other specifies the exact amount and details. It is a duplication of data, but it allows the many features of Hugo taxonomies to be fully utilized.

{{< highlight toml >}}
ingredients = [
  "beets",
  "celery",
  ...
]
recipeIngredients = [
  "**FOR SALAD",
  "5 Beets",
  "½ heart of celery",
  ...
]
{{< /highlight >}}

You add ingredients to the taxonomy by including them in the front matter of your pages. Alternatively, you can create pages in the directory path where they land to add intro text, images, or additional parameters in the front matter. For instance, the page about [mushrooms]({{< relref "/ingredients/mushrooms" >}}) is created automatically without anything added to your content directory. However, if you wish to add to it, simply create a list page in the correct location. In this instance, the following page is in the content directory: ./content/ingredients/mushrooms/_index.md.

{{< highlight-github
      owner=benstraw
      repo=benstrawbridge.com
      path=content/ingredients/mushrooms/_index.md
      lang=hugo-html-template
      showlink=false
>}}

These taxonomy pages will ultimately lead to being able to create related content features and pull in lists of content or products with similar taxonomic themes.

