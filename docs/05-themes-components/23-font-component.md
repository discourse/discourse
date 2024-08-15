---
title: Create and share a font theme component
short_title: Font component
id: font-component

---
Discourse supports importing themes containing assets from a remote repository. 

This allows theme authors to share fonts and images.


### Create a new git repository with the font

```text
mkdir discourse-roboto-theme
cd discourse-roboto-theme
git init .
vim about.json
```

For `about.json` add a skeleton config file

```text
{
   "name" : "Roboto theme component",
   "about_url" : "",
   "license_url": "",
   "assets": {
        "roboto": "assets/roboto.woff2"
   }
}
```

Add a `LICENSE` file, I [usually use MIT](https://github.com/SamSaffron/discourse-solarized/blob/master/LICENSE)

```text
vim LICENSE
```

### Download the font

http://localfont.com/ is a handy site to get fonts

```text
mkdir assets
cp ~/Downloads/roboto.woff2 roboto.woff2
```

### Add CSS that consumes the theme

```text
mkdir common
cd common
```
Create a file called `common.scss` with

```css
@font-face {
  font-family: Roboto;
  src: url($roboto) format('woff2')
}

body {
    font-family: Roboto;
}
```

### Push changes to GitHub

Check in all your changes:

```text
git add LICENSE
git add about.json
git add assets/roboto.woff2
git add common/common.scss
git commit -am "first commit"
```

Create an account on [GitHub.com](https://github.com) and then create a new repository. 

### (Optional) create a topic on Discourse as a home to discuss your colors

Ideally you would create a topic in the #plugin:theme category with some screenshots of your color scheme. You will use this as your `about_url`

### Fill in the missing information in your about.json file

- Navigate to your LICENSE page on GitHub, fill in that URL as your `license_url`

- Either use the GitHub project URL or Discourse topic URL as your `about_url` 

At the end of the process your about.json file will look something like:

```json
{
   "name" : "Roboto theme component",
   "about_url": "https://github.com/SamSaffron/discourse-roboto-theme",
   "license_url": "https://github.com/SamSaffron/discourse-roboto-theme/blob/master/LICENSE",
   "assets": {
        "roboto": "assets/roboto.woff2"
   }
}

```


Check in the change and push to GitHub

```text
git commit -am "added more details"
git push
```

### Test your font component

- In the `admin/customize/theme` screen import your theme from GitHub

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/4/2/421dbfd15c3f35c0d5a97ad1b6dc78dd1c094385.png" width="690" height="278">



:confetti_ball: 

You can now easily share fonts!

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/7/3/73748bb31adedc3dad3bd65c02d0e1554dc31eb5.png" width="235" height="499">

See also: 

https://meta.discourse.org/t/how-to-develop-custom-themes/60848
