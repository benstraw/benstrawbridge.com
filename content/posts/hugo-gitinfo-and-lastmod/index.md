+++
title = 'Hugo Gitinfo and Lastmod'
date = 2024-06-07T09:43:00-07:00
draft = true
# summary = ""
# categories = [""]
tags = [
  "Hugo",
  "GitInfo"
  ]
# featured_image = ""
# homeFeatureIcon = ""
# showTOC = true
+++

## In theory using last mod is a good idea for sorting Hugo collections.

Just be careful and think it through, because you may change the file more than you thought even if you don't change the content. If you update the front matter because you added a param to your system, or you change your summary so you now require a `<!-- more -->` element on the page, all of those will be commited to github and thus will end up with a new LastMode timestamp. Completely obvious of course, unless you forget to think about that... Even a mature system seemingly not changing may change at any time and completely through off your sort order.

{{< highlight go-html-template >}}
  {{- range Site.Pages.ByLastmod.Reverse  }}
{{< /highlight >}} 

<!--more-->