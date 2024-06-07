+++
title = 'Pines Image Gallery With Hugo'
date = 2024-03-13T12:15:57-07:00
tags = [
  "Hugo",
  "Image Gallery",
  "Pines",
  "Alpine.js",
  "Tailwind CSS",
  "Web Development",
  "Open Source",
  "Templates",
  "State Management",
  "Accessibility"
]
# draft = true
homeFeatureIcon = "fa-solid fa-images"
+++

The first place I used this is on the recipe page about my mom's [family recipe cookbook]({{< ref "/posts/moms-family-recipes-cookbook" >}} "About Us")

<!--more-->

## Setting up the pines open source image gallery to work with Hugo

[Open source image-gallery from devdojo pines project](https://devdojo.com/pines/docs/image-gallery) integrated with hugo as a partial that loads and optimizes the images.

The image gallery uses Alpine.js and tailwind css libraries, which are used for this hugo theme as well, so I incorporated it into a hugo partial.

### Some of the key features and functionalities:

**Data Structure**: There is an array imageGallery containing objects with photo and alt properties. This data structure holds the information for each image in the gallery.  

**State Management**: Alpine.js manages the state of the image gallery through reactive variables like imageGalleryOpened, imageGalleryActiveUrl, and imageGalleryImageIndex.  

**Event Handlers**: There are defined methods like imageGalleryOpen, imageGalleryClose, imageGalleryNext, and imageGalleryPrev to handle various interactions such as opening the gallery, closing it, and navigating between images.  

**Event Listeners**: There are event listeners for keyboard events (keyup) and custom events (@image-gallery-next.window, @image-gallery-prev.window) to trigger navigation between images.  

**Template Rendering**: The template markup iterates over the imageGallery array using x-for to generate image thumbnails. Each thumbnail has a click event (x-on:click="imageGalleryOpen") to open the gallery and display the respective image.  

**Teleporting**: The modal containing the full-size image is teleported to the body for proper z-index stacking and ensures it's positioned correctly within the DOM hierarchy.  

**Transitions and Animations**: Smooth transitions are applied when opening and closing the modal (x-transition directives).  

**Navigation Controls**: Navigation controls (previous and next buttons) are placed within the modal to allow users to navigate between images easily.  

**Accessibility**: The implementation considers accessibility by providing keyboard navigation (@keydown.window.escape) and ensuring focus management within the modal.  

## Integrating with Hugo 

To get this going with hugo, I just needed to make one change, which was to build the array of images with the hugo template from a set of images in the same directory as the code.

### Creating the imageGallery array

```go
{{ $photos := sort (.Resources.ByType "image") (index .Params "sort_by" | default "Name") (.Params.sort_order | default "asc") }}

{{ $imageGallery := slice }}
{{ range $index, $photo := $photos }}
    {{ $image := dict "photo" $photo.RelPermalink "alt" $photo.Name }}
    {{ $imageGallery = $imageGallery | append $image }}
{{ end }}
```

then, in the alpinejs section, you just drop that in -

```js
<div x-data="{
  imageGalleryOpened: false,
  imageGalleryActiveUrl: null,
  imageGalleryImageIndex: null,
  imageGallery: {{ $imageGallery | jsonify }}, // Pass the JSON-encoded imageGallery array
  // Rest of the Alpine.js code
}">
```

### Adding it to a template 

Finally, I saved it as `page_gallery.html` in the partials direcotry, and added it to my template by detecting a param that triggers it.


```hugo
{{ if .Param "photoGalleryTitle" }}
  <h2 class=" rounded-t-lg mb-1 p-3 flex items-center {{ $headerClass }}">{{ .Param "photoGalleryTitle" }}</h2>
  {{- partial "page_gallery.html" . -}}
{{ end }}
```

Thats it for now. In the future I will make more adjustments to this code to add captions, and suit my needs as the website progresses.

If you like it, try it out in my theme for Hugo - the [Ryder Theme](https://github.com/arts-link/ryder).

## TODO

- make images directly linkable
- use hugo to optimize images for responsive formats
- add captions