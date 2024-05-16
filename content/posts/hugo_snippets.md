+++
title = 'Hugo Snippets'
date = 2024-02-12T12:46:55-08:00
# draft = true
+++

## Get the first of something in a collection

For example the first jpg image in the current directory starting with the word `feature`.

```
{{ $first := index (.Page.Resources.Match "feature*.jpg") 0 }}
```

## Get a param from either hugo.toml or front matter

For example, you have a variable set in hugo.toml, but you want a section to be different.

```hugo.toml
[params]
  logo_title = 'Home'
```
In front matter the `logo_title` is overridden and takes precedence on the page.
```content/posts/_index.md
+++
logo_title = 'Posts'
+++
{{ with .Param "logo_title" }}
<h1>{{ . }}</h1>
{{- end -}}
```

## Split, append to and rejoin a string

I've always found it easier and cleaner to work with arrays than strings when I need to add or remove things from them. In this case I have my tailwindcss classes for the header in a string, space seperated of course.

```go
{{ $headerClass := split "bg-gradient-to-r from-cyan-500 to-cyan-800" " " }} 
```

First you split it and it become a list. Now you can easily run through a bunch of configurable params to see if they need to be added to the header classes and add them with append.

```go
{{ $headerClass = $headerClass | append . }}
```

Finally, when you are done manipulating the [hugo collection](https://gohugo.io/functions/collections/), just turn it back into a string with `delimit`.

```go
{{ $headerClass = delimit $headerClass " " }}
```