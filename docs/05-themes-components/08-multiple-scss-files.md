---
title: Split up theme SCSS into multiple files
short_title: Multiple SCSS files
id: multiple-scss-files

---
Themes and theme components are becoming steadily more powerful, and developers are getting more and more ambitious. To make things easier for developers, themes can now split their SCSS into multiple files. 

https://github.com/discourse/discourse/commit/268d4d4c828a0d9e3ca6b0b5b623db85eb32b9f3

When creating a new theme with the [theme CLI](https://meta.discourse.org/t/beginners-guide-to-using-theme-creator-and-theme-cli-to-start-building-a-discourse-theme/108444), or sharing a theme [on github](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848), simply create a new folder called `scss`. Fill it with your `.scss` files, following any folder structure, and all the files will be available for you to import in the common / desktop / mobile SCSS sections of your theme.

For example, if you want to have a common variable available to both mobile and desktop SCSS, you could do something like this:

**scss/myfolder/variables.scss**
```
$favourite-color = red;
```

**desktop/desktop.scss**
```scss
@import "myfolder/variables";
body {
  background-color: $favourite-color;
}
```

**mobile/mobile.scss**
```scss
@import "myfolder/variables";
body {
  color: $favourite-color;
}
```

This feature was added in `v2.3.0.beta8`, so do not use these features quite yet if you need to maintain backwards compatibility with older versions of Discourse. You can use the [`minimum_discourse_version` parameter of `about.json`](https://meta.discourse.org/t/structure-of-themes-and-theme-components/60848) to ensure your component doesn't get used on an earlier version.
