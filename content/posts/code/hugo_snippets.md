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

## Get a param from either hugo.tom or front matter

For example, you have a variable set in hugo.toml, but you want a section to be different.

```hugo.toml
logo_title = 'home'
```

```
{{ with .Param "logo_title" }}
<h1>{{ . }}</h1>
{{- end -}}
```
