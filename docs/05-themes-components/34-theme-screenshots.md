---
title: Adding preview screenshots to Discourse themes
short_title: Theme screenshots
id: theme-screenshots
---

<div data-theme-toc="true"> </div>

> :bookmark: This guide explains how to add preview screenshots to your Discourse theme to showcase how it looks in both light and dark modes.
>
> :person_raising_hand: Required user: Theme developers

Adding preview screenshots to your Discourse theme helps users quickly understand how your theme looks before they install it. This guide will walk you through adding light and dark mode screenshots to your theme.

## Creating the screenshots folder

To add preview screenshots to your theme:

1. Create a folder called `screenshots` in the root directory of your theme
2. Add two image files to this folder:
   - `light.png` - Shows your theme in light mode
   - `dark.png` - Shows your theme in dark mode

## Setting up the image files

Your screenshot images must meet these requirements:

- **Ratio**: 16:9 aspect ratio
- **Dimensions**: 2560 × 1440 pixels (recommended)
- **File size**: Under 1MB per image
- **Format**: PNG format

> :information_source: Using the recommended dimensions ensures your screenshots look crisp on high-resolution displays while maintaining reasonable file sizes.

## Updating the about.json file

After creating your screenshots, you need to update your theme’s `about.json` file to include references to these images:

1. Open your theme’s `about.json` file
2. Add the `screenshots` array to the JSON object:

```json
  "screenshots": ["screenshots/light.png", "screenshots/dark.png"]
```

## Best practices for theme screenshots

### Capturing your theme

When taking screenshots of your theme:

- Show the main interface components that make your theme unique.
- Include examples of your theme’s color palette and typography.
- Ensure both screenshots show the same view for easy comparison.
- Use realistic content rather than placeholder text where possible.

### Image optimization

Keep your images under the 1MB size limit by:

- Using PNG optimization tools like [TinyPNG](https://tinypng.com/) or [ImageOptim](https://imageoptim.com/).
- Removing unnecessary metadata from image files.
- Considering slightly reduced dimensions if needed while maintaining the 16:9 ratio.

## Common issues and solutions

### Images not appearing in theme preview

**Issue**: Screenshots don’t appear when viewing the theme in the admin panel.

**Solution**: Verify that:

1. Your file names in `about.json` exactly match the actual file names (these are case-sensitive).
2. The images are properly uploaded to the theme’s repository in the `screenshots` folder.

### File size too large

**Issue**: Image files exceed the 1MB limit.

**Solution**:

1. Use image optimization tools to reduce file size.
2. Reduce image dimensions while maintaining the 16:9 ratio.
3. Consider using a more efficient compression method.

## FAQs

**Q: Do I need both light and dark screenshots?**
A: Yes, providing both light and dark mode screenshots is required to show how your theme appears in each mode. If you don’t have two different modes, use the same image for both.

**Q: Can I use a different image format than PNG?**
A: PNG is recommended for its balance of quality and size. While other formats might work, PNG is the standard for Discourse theme screenshots.

**Q: How do I take good screenshots of my theme?**
A: Use a full-screen browser window at 2560×1440 resolution with developer tools closed. Set your theme to light mode for one screenshot and dark mode for the other.

## Additional resources

- https://meta.discourse.org/t/beginners-guide-to-using-discourse-themes/91966
- https://meta.discourse.org/t/developer-s-guide-to-discourse-themes/93648
