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
hugo server
```
