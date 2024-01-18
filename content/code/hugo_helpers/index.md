+++
title = 'Hugo Helpers'
date = 2024-01-12T11:22:17-08:00
# draft = true
description = "Hugo helpers will help your hugo, make a great hugo!"
category = "web development"
tags = ["hugo","partials","images","responsive"]
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

### partials/alert.html  

This one passes the variables within the page context by using `.Scratch.set "var1" "val1"` in the calling template. It is used to create alert boxes in various different styles.

```go
{{/*  
  Based on: https://flowbite.com/docs/components/alerts/  
    
  Usage::
    {{- .Scratch.Set "alertType" "success"}}
    {{- .Scratch.Set "alertTitle" "Alpha Release" }}
    {{- .Scratch.Set "alertMessage" "You are viewing an alpha version of this site redesign. Things may be broken at times or just in a state of flux." }}
    {{- partial "alert.html" . }}
*/}}
{{ $alertType := .Scratch.Get "alertType" }}
{{ $alertTitle := .Scratch.Get "alertTitle" }}
{{ $alertMessage := .Scratch.Get "alertMessage" }}
{{ $alertClasses := "" }}
{{ if eq $alertType "info" }}
  {{ $alertClasses = "text-blue-800 border-blue-300 bg-blue-50 dark:text-blue-400 dark:border-blue-800" }}
{{ else if eq $alertType "danger" }}
  {{ $alertClasses = "text-red-800 border-red-300 bg-red-50 dark:text-red-400 dark:border-red-800" }}
{{ else if eq $alertType "success" }}
  {{ $alertClasses = "text-green-800 border-green-300 bg-green-50 dark:text-green-400 dark:border-green-800" }}
{{ else if eq $alertType "warning" }}
  {{ $alertClasses = "text-yellow-800 border-yellow-300 bg-yellow-50 dark:text-yellow-400 dark:border-yellow-800" }}
{{ else }}
  {{ $alertClasses = "text-gray-800 border-gray-300 bg-gray-50 dark:text-gray-400 dark:border-gray-800" }}
{{ end }}

<div class="flex items-center p-4 mb-4 text-sm border rounded-lg  dark:bg-gray-800 {{ $alertClasses }}" role="alert">
  <i class="fa-solid fa-circle-info flex-shrink-0 inline w-4 h-4 me-3"></i>
  <span class="sr-only">{{ $alertType }}</span>
  <div>
    <span class="font-medium">{{ $alertTitle }}</span> {{ $alertMessage }}
  </div>
</div>
```


