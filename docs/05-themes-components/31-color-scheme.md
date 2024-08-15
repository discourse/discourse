---
title: Create and share a color scheme
short_title: Color scheme
id: color-scheme

---
<div data-theme-toc="true"> </div>

Discourse now supports importing color schemes from remote repository. Here I will demonstrate how you would go about doing this. 

### Navigate to colors and add a color scheme.

Head to `/admin/customize/colors` on your site and create a color scheme.

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/b/7/b7fced237ee399d52c634a3ab6fcc9416db65605.png" width="690" height="451">

Tips: 

- I used a chrome plugin ([color picker](https://chrome.google.com/webstore/detail/colorpick-eyedropper/ohcpnigalekghcmgcdcenkpelffpdolg?hl=en)) to select colors from an existing image of a palette on the web. 

- If you create a theme, assign the color scheme to the theme and preview it, changes will be reflected live.

### Create a new git repository with the color scheme

```text
mkdir my-awesome-scheme
cd my-awesome-scheme
git init .
vim about.json
```

For `about.json` add a skeleton config file

```text
{
   "name" : "My awesome color schemes",
   "about_url" : "",
   "license_url": "",
   "color_schemes": {
   }
}
```

Add a `LICENSE` file, I [usually use MIT](https://github.com/SamSaffron/discourse-solarized/blob/master/LICENSE)

```text
vim LICENSE
```

### Push changes to GitHub

Check in all your changes:

```text
git add LICENSE
git add about.json
git commit -am "first commit"
```

Create an account on [GitHub.com](https://github.com) and then create a new repository. 

### (Optional) create a topic on Discourse as a home to discuss your colors

Ideally you would create a topic in the #plugin:theme category with some screenshots of your color scheme. You will use this as your `about_url`

### Fill in the missing information in your about.json file

- Navigate to your LICENSE page on GitHub, fill in that URL as your `license_url`

- Either use the GitHub project URL or Discourse topic URL as your `about_url` 

- Press `Copy to Clipboard` on your color scheme and paste that in to the color_schemes section

At the end of the process your about.json file will look something like:

```json
{
   "name" : "Solarized",
   "about_url" : "https://github.com/SamSaffron/discourse-solarized",
   "license_url": "https://github.com/SamSaffron/discourse-solarized/blob/master/LICENSE",
   "color_schemes": {
      "Solarized Light": {
        "primary": "586E75",
        "secondary": "EEE8D5",
        "tertiary": "268BD2",
        "quaternary": "CB4B16",
        "header_background": "002B36",
        "header_primary": "93A1A1",
        "highlight": "B58900",
        "danger": "CB4B16",
        "success": "859900",
        "love": "DC322F"
      }
   }
}
```

Check in the change and push to GitHub

```text
git commit -am "added more details"
git push
```

### Test your color scheme is correct

- Delete your local color scheme
- In the `admin/customize/theme` screen import your theme from GitHub

<img src="//assets-meta-cdck-prod-meta.s3.dualstack.us-west-1.amazonaws.com/original/3X/4/2/421dbfd15c3f35c0d5a97ad1b6dc78dd1c094385.png" width="690" height="278">

- Visit `admin/customize/colors` and ensure your color scheme looks correct. 

:confetti_ball: 

You can now easily share your color scheme with others! 

See also: 

https://meta.discourse.org/t/how-to-develop-custom-themes/60848


---
*Last Reviewed by @SaraDev on [date=2022-06-02 time=18:00:00 timezone="America/Los_Angeles"]*
