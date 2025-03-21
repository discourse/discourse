function isLoaded(img) {
  // In Safari, img.complete sometimes returns true even when the image is not loaded.
  // naturalHeight seems to be a more reliable check
  return !!img.naturalHeight;
}

export function nativeLazyLoading(api) {
  api.decorateCookedElement((element, helper) => {
    if (helper.getModel()) {
      // We only want to lazy load images in the post-stream, not the composer
      // (Safari in particular is very bad at re-rendering lazy-loaded images smoothly)
      element.querySelectorAll("img").forEach((img) => (img.loading = "lazy"));
    }
  });

  api.decorateCookedElement(
    (post) => {
      const siteSettings = api.container.lookup("service:site-settings");

      post.querySelectorAll("img").forEach((img) => {
        // Support for smallUpload should be maintained until Post::BAKED_VERSION is bumped higher than 2
        const { smallUpload, dominantColor } = img.dataset;

        if (siteSettings.secure_uploads && smallUpload) {
          // Secure uploads requests go through the app. In topics with many images,
          // this makes it very easy to hit rate limiters. Skipping the low-res
          // placeholders reduces the chance of this problem occuring.
          return;
        }

        if ((smallUpload || dominantColor) && !isLoaded(img)) {
          if (!img.onload) {
            img.onload = () => {
              img.style.removeProperty("background-image");
              img.style.removeProperty("background-size");
              img.style.removeProperty("background-color");
            };
          }

          if (smallUpload) {
            img.style.setProperty("background-image", `url(${smallUpload})`);
            img.style.setProperty("background-size", "cover");
          } else {
            img.style.setProperty("background-color", `#${dominantColor}`);
          }
        }
      });
    },
    {
      afterAdopt: true,
    }
  );
}
