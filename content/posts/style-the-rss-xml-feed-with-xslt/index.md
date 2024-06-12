+++
title = 'Styling a RSS feed With XSL'
date = 2024-02-18T23:14:08-08:00
# draft = true
tags = [
  "RSS",
  "XSLT",
  "XML",
  "Hugo",
  "Web Development",
  "Styling Feeds",
  "Feed Readers",
  "Blogging",
  "Templates",
  "Tutorial"
]
homeFeatureIcon = "fa-solid fa-code-merge"
+++

> A styled RSS feed makes your site more usable

When you put a link to your rss / atom feed on your website it is a link to a raw xml file designed for feed readers such as feedly to import them and provide the reader with all their internet in one place.

<!--more-->

XML is code, and doesn't look great. If you unsuspectingly click on that {{< font-awesome fa-solid fa-rss >}} Feed icon, and land on a blob of XML you will probably be confused. To fix that, you can use a tool called XSLT to style the XML so it looks like a webpage in your browser.

### An easy solution

A [techie/blogger named Matt Webb](https://interconnected.org/) created a project called [about feeds](https://aboutfeeds.com/) and provides a free xslt template you can use to make your rss feed look nice ([like mine does now](/index.xml)) and [put it on github](https://github.com/genmon/aboutfeeds) for all the world to share.

If you want to do this on your website, all you have to do is add the xslt to the xml header, kind of like you would with css and html.

```
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<?xml-stylesheet href="/pretty-feed-v3.2e3803f6bd61.xsl" type="text/xsl"?>
<rss version="2.0" xmlns:atom="http://www.w3.org/2005/Atom">
  <channel>
...
```

### Doing this in Hugo

If you are working in hugo, you will need to override the default hugo template, which is a little be scary to override one of the internal templates in case they update it, but the rss template is pretty stable and you _can_ keep an eye on [the source for that internnal template](https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml).

What you do is create a new file, call it rss.xml and place it in your `/layouts/_default` directory and copy that entire [rss xml internal template](https://github.com/gohugoio/hugo/blob/master/tpl/tplimpl/embedded/templates/_default/rss.xml) from github and pasted it into your new rss.xml file.  Then just add this one line of code after the opening `<?xml>` tag.

```go
{{- printf "<?xml-stylesheet href="/xls/pretty-feed-v3.2e3803f6bd61.xsl" type="text/xsl"?>" | safeHTML }}
```

If you don't have an rss feed for your hugo site, or need to customize what it links to you can learn more about that on the hugo docs site [rss section](https://gohugo.io/templates/rss/).

Incidentally, doing this brought me back to xslt for the first time in a long time. I wrote xslt sample code for [SAMS Teach Yourself SVG in 24 Hours](https://www.amazon.com/Sams-Teach-Yourself-SVG-Hours/dp/0672322900) was back in 2001 with [Micah Laaker]() (the extra "A" is for extra "Hot!")