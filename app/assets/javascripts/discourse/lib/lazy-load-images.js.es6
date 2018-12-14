const OBSERVER_OPTIONS = {
  rootMargin: "50%" // load images slightly before they're visible
};

const imageSources = new WeakMap();

const LOADING_DATA =
  "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";

// We hide an image by replacing it with a transparent gif
function hide(image) {
  image.classList.add("d-lazyload");
  image.classList.add("d-lazyload-hidden");

  imageSources.set(image, {
    src: image.getAttribute("src"),
    srcSet: image.getAttribute("srcset")
  });
  image.removeAttribute("srcset");

  image.setAttribute(
    "src",
    image.getAttribute("data-small-upload") || LOADING_DATA
  );
  image.removeAttribute("data-small-upload");
}

// Restore an image when onscreen
function show(image) {
  let sources = imageSources.get(image);
  if (sources) {
    image.setAttribute("src", sources.src);
    if (sources.srcSet) {
      image.setAttribute("srcset", sources.srcSet);
    }
  }
  image.classList.remove("d-lazyload-hidden");
}

export function setupLazyLoading(api) {
  // Old IE don't support this API
  if (!("IntersectionObserver" in window)) {
    return;
  }

  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      const { target } = entry;

      if (entry.isIntersecting) {
        show(target);
        observer.unobserve(target);
      } else {
        // The Observer is triggered when entries are added. This allows
        // us to hide things that start off screen.
        hide(target);
      }
    });
  }, OBSERVER_OPTIONS);

  api.decorateCooked($post => {
    $(".lightbox img", $post).each((_, $img) => observer.observe($img));
  });
}
