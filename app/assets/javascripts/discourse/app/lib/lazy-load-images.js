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
                img.removeAttribute("style");
              };
            }

            img.style = `background-image: url(${img.dataset.smallUpload}); background-size: cover;`;
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
