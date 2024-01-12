+++
title = 'Hugo Helpers'
date = 2024-01-12T11:22:17-08:00
draft = true
description = "Hugo helpers will help your hugo, make a great hugo!"
+++

Here are some useful partials I use in this theme.  

### layouts/_default/_markup/render-image.html 

This replaces the default markup template for rendering an image when the marking code `![Alt Text](/path/to/img.jpg)` is used. It calls another partial you have to add to your theme or layout directory in your site called ImageConverter.

```go
{{ $image := resources.Get .Destination }}
{{- if $image -}}
{{- $post_image_webp := partial "ImageConverter.html" (dict "ImageSrc" .Destination "ImgParam" (printf "%dx%d webp q100" $image.Width $image.Height)) -}}
{{- $post_image_jpg := partial "ImageConverter.html" (dict "ImageSrc" .Destination "ImgParam" (printf "%dx%d jpg q100" $image.Width $image.Height)) -}}
<picture>
    <source srcset="{{ $post_image_webp }}" type="image/webp">
    <source srcset="{{ $post_image_jpg }}" type="image/jpeg">
    <img loading="lazy" class="img-fluid" src="{{ $post_image_jpg }}" width="{{ $image.Width }}" height="{{ $image.Height  }}" {{ with .Text}} alt="{{ . }}" {{ else }} alt="{{ .Page.Title }}" {{ end }} {{ with .Title}} title="{{ . }}"{{ end }}>
</picture>
{{- else -}}
  <img loading="lazy" class="img-fluid" src="{{ .Destination | safeURL }}" {{ with .Text}} alt="{{ . }}" {{ else }} alt="{{ .Page.Title }}" {{ end }} {{ with .Title}} title="{{ . }}"{{ end }} />
{{- end -}}
```

### layouts/partials/ImageConverter.html

This uses the power of [hugo image processing](https://gohugo.io/content-management/image-processing/) to optimize your images and convert them to webp or other types.

```go
{{/* Step 1: A default image as fallback */}}
{{ $image := "/images/placeholder.png" }} 

{{/* Step 2: now check if passed image exists with same as title */}}
{{ $image_url := resources.Get .ImageSrc }}
{{ $img_param := .ImgParam }}

{{ if $image_url }} 
    {{/* Resize and convert the image  */}}
    {{ $image_url = $image_url.Resize  $img_param }}
    {{ $image = $image_url.RelPermalink }}             
{{end}}

{{return $image}}
```