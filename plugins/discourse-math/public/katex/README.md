
## How to update KaTeX for Discourse without building

1. Fetch the latest release tarball
2. Copy fonts
3. Copy JS and CSS
4. Replace font paths in CSS

```bash
DMPATH=/path/to/discourse-math  # set this to your path to the discourse-math repo
cd /tmp
wget -O- https://github.com/KaTeX/KaTeX/releases/latest/download/katex.tar.gz | tar -zx
cp katex/fonts/*.woff* $DMPATH/public/katex/fonts/
cp katex/katex.min.* katex/contrib/{mhchem,copy-tex}.min.js $DMPATH/public/katex/
sed -i "s~url(fonts/~url(/plugins/discourse-math/katex/fonts/~g" $DMPATH/public/katex/katex.min.css
```

## How to build KaTeX for Discourse

1. `git clone https://github.com/KaTeX/KaTeX.git && cd KaTeX`

    `git submodule update --init --recursive`

2. Disable TTF fonts:

   `export USE_TTF=false`

3. Run build to fetch the fonts into `dist/fonts/`

   `npm run build`

4. Copy fonts to this plugin

   `cp dist/fonts/* discourse-math/public/katex/fonts/`

5. Change paths to fonts ((otherwise the fonts won't load in Discourse):

    `sed -ri 's/@font-folder.+$/@font-folder:
"\/plugins\/discourse-math\/katex\/fonts";/'
submodules/katex-fonts/fonts.less`

3. Build KaTeX:

   `yarn && yarn builld`

4. Copy `katex.min.js` and `katex.min.css` from `dist/` to
`discourse-math/public/katex/`

