// Min size in pixels for consideration for lazy loading
const MINIMUM_SIZE = 150;

function forEachImage(post, callback) {
  post.querySelectorAll("img").forEach((img) => {
    if (img.width >= MINIMUM_SIZE && img.height >= MINIMUM_SIZE) {
      callback(img);
    }
  });
}

export function nativeLazyLoading(api) {
  api.decorateCookedElement(
    (post) =>
      forEachImage(post, (img) => {
        img.loading = "lazy";
        if (img.dataset.smallUpload) {
          if (!img.complete) {
            if (!img.onload) {
              img.onload = () => {
                img.style.removeProperty("background-image");
                img.style.removeProperty("background-size");
              };
            }

            img.style.setProperty(
              "background-image",
              `url(${img.dataset.smallUpload});`
            );
            img.style.setProperty("background-size", "cover");
          }
        }
      }),
    {
      onlyStream: true,
      id: "discourse-lazy-load-after-adopt",
      afterAdopt: true,
    }
  );
}
