+++
title = 'Helpful Hugo Things'
date = 2024-09-19T11:39:40-07:00
draft = true
# I like this by default now... keeps the page full width with tags below.
hideAsideBar = true
# summary = ""
# # categories = [""]
# tags = [
  # ""
  # ]
# featured_image = ""
# homeFeatureIcon = ""
# showTOC = true
+++

``` | plainify | htmlUnescape | chomp ```

```
   {{- range .GetTerms "tags" | first 6 }}
```
<!--more-->