---
title: Change the style of a wiki post
short_title: Wiki post style
id: wiki-post-style
---

A quick guide to change the style of your wiki posts:

![image|525x499,75%](/assets/wiki-post-style-1.png)

### Change the background color:

In your `/admin/customize/themes` add this CSS under `Common > CSS`

```css
.wiki .topic-body .cooked {
  background-color: #dcffdc; /*light green*/
}
```

### Change text size

If you want you can also change the font used or the size of the text, even the color

```css
.wiki .topic-body .cooked p {
  font-size: 18px;
  color: green;
}
```

![image|495x500,75%](/assets/wiki-post-style-2.png)

### Add text

You can add a text to make clear to users that what they are watching is a wiki post

```css
.post-info.edits .wiki::before {
  content: "EDIT THIS WIKI POST";
  color: green;
  background-color: #d2e2d2;
  margin-right: 3px;
  font-weight: bold;
  border: 1px solid green;
  padding: 3px;
}
```

![image|355x213,75%](/assets/wiki-post-style-3.png)
