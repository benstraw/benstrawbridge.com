+++
title = 'Book Store Sample Data'
date = 2024-05-17T13:36:56-07:00
# draft = true
tags = [
  "Content Adaptors",
  "Hugo",
  "Static Site Generator",
  "API Integration",
  "Dynamic Content"
]

+++



## Example

I just followed [the example here on the hugo docs](https://gohugo.io/content-management/content-adapters/#example) to set up the simple books demo, but I intend to use this new feature to build out some great new dynamic content for content marketing purposes, such as lists of top products.

<!--more-->

### Small changes to my single.html

I added changes to fit my template better and a link to buy the book on amazon with a search link searching for the isbn. I haven't figured out a way to link by isbn directly, you could do that years ago when I last messed with that stuff, but now the isbn is 13 digits and the asin is only 10.

{{< highlight go-html-template >}}
<a href="https://www.amazon.com/s?k={{ $isbn }}&tag=grrquarterly-20" class="bg-blue-500 hover:bg-blue-700 text-white font-bold py-2 px-4 rounded">
  Buy it Now 
</a>
{{< /highlight >}}
