# benstrawbridge.com landing page

## inital setup
...
```bash
hugo new site benstrawbridge.com
cd benstrawbridge.com
mkdir config
mkdir config/_default
mkdir config/production
mv hugo.toml config/_default
git init -b main
hugo new content _index.md
cp ../<other_hugo_site>/.gitignore .
hugo new theme benstraw
echo "theme = benstraw" >> config/_default/hugo.toml
```

## adding tailwindcss to the theme

[resource for setting up hugo with tailwindcss](https://www.unsungnovelty.org/posts/03/2022/how-to-add-tailwind-css-3-to-a-hugo-website-in-2022/)
[hugo pipes stuff for postProcess](https://gohugo.io/hugo-pipes/postprocess/)

Make sure to update `tailwind.config.js`, `package.json`, `main.css` and the css include link.

```bash
cd themes/benstraw
npm init -y
npm install --save-dev tailwindcss
npx tailwindcss init
touch assets/css/style.css
npm run build-tw
```

make sure you update the build to install the stuff that is needed

```bash
npm install -D postcss-cli tailwindcss postcss autoprefixer @tailwindcss/typography
```

### Links

- https://www.markusantonwolf.com/blog/guide-for-different-ways-to-access-your-image-resources/
- https://devnodes.in/blog/hugo/image-convert-to-webp/
- https://martijnvanvreeden.nl/hugo-shortcode-to-serve-images-in-next-gen-formats/
- this is how to make a good resume: https://mertbakir.gitlab.io/resume/
  -- https://gitlab.com/mertbakir/resume-a4

### Page Title

The title was being formatted like this:

```
  <title>{{ if .IsHome }}{{ site.Title }}{{ else }}{{ printf "%s | %s" .Title site.Title }}{{ end }}</title>
```

Very standard stuff, probably straight from the default template. I am updating it to use "SectionTitle" param as follows

```
[cascade]
  sectionTitle = "Recipes on BenStrawbridge.com"
```

```bash
➜  content git:(main) ✗ tree -d
.
├── consulting
|   |__ **Section Title: Ben Strawbridge Dot Com Consulting**
├── fineprint
|   |__ **Section Title: The Fineprint on Ben Strawbridge Dot Com**
├── ingredients
|   |__ **Section Title: Recipe Ingredients on Ben Strawbridge Dot Com**
├── portfolio
├── posts
│   ├── links
|   |__ **Section Title: Link Graveyard on Ben Strawbridge Dot Com**
├── projects
|   |__ **Section Title: Projects on Ben Strawbridge Dot Com**
│   ├── hiking
|   |__ **Section Title: Hikes on Ben Strawbridge Dot Com**
│   ├── recipes
|   |__ **Section Title: Recipes on Ben Strawbridge Dot Com**
```