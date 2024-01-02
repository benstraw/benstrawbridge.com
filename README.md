# benstrawbridge.com landing page  

## inital setup  

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

Make sure to update `tailwind.config.js`, `package.json`, `main.css` and the css include link.

```bash
cd themes/benstraw
npm init -y
npm install --save-dev tailwindcss
npx tailwindcss init
touch assets/css/style.css
npm run build-tw
```
