+++
title = '{{ replace .File.ContentBaseName "-" " " | title }}'
date = {{ .Date }}
draft = true
# I like this by default now... keeps the page full width with tags below.
hideAsideBar = true
# summary = ""
categories = ["recipe"]
# tags = [
#   ""
#   ]
# featured_image = ""
# homeFeatureIcon = "fa-solid fa-kitchen-set"
# showTOC = true

recipe = true
recipeCuisine = American
prepTime = PT20M
cookTime = PT20M
totalTime = PT20M
recipeYield = [""]
calories = 270
recipeIngredient = [""]
recipeInstructions = ["..."]
+++

## Ingredients
{{< recipe-ingredients-list >}}

<!--more-->

## Instructions
{{< recipe-howto-steps-list >}}

{{< alert-wrapper alertType="info" alertTitle="View the Full Book" alertMessage="Check out every page of the cookbook over at the original post." alertCTA="/posts/moms-family-recipes-cookbook/" >}}