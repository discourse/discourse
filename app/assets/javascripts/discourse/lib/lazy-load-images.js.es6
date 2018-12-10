const OBSERVER_OPTIONS = {
  rootMargin: "50%" // load images slightly before they're visible
};

// We hide an image by replacing it with a transparent gif
function hide(image) {
  image.classList.add("d-lazyload");
  image.classList.add("d-lazyload-hidden");
  image.setAttribute("data-src", image.getAttribute("src"));
  image.setAttribute(
    "src",
    "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw=="
  );
}

// Restore an image from the `data-src` attribute
function show(image) {
  let dataSrc = image.getAttribute("data-src");
  if (dataSrc) {
    image.setAttribute("src", dataSrc);
    image.classList.remove("d-lazyload-hidden");
  }
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
