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
    const copyImg = new Image();
    copyImg.onload = () => {
      image.src = copyImg.src;
      if (copyImg.srcset) {
        image.srcset = copyImg.srcset;
      }
      image.classList.remove("d-lazyload-hidden");
      image.parentNode.removeChild(copyImg);
      copyImg.onload = null;
    };

    copyImg.src = sources.src;
    if (sources.srcSet) {
      copyImg.srcset = sources.srcSet;
    }

    copyImg.style.position = "absolute";
    copyImg.style.top = 0;
    copyImg.style.left = 0;
    copyImg.style.height = "100%";
    copyImg.style.width = "100%";

    image.parentNode.appendChild(copyImg);
  } else {
    image.classList.remove("d-lazyload-hidden");
  }
}

export function setupLazyLoading(api) {
  const observer = new IntersectionObserver(entries => {
    entries.forEach(entry => {
      const { target } = entry;

      if (entry.isIntersecting) {
        show(target);
        observer.unobserve(target);
      }
    });
  }, OBSERVER_OPTIONS);

  api.decorateCooked($post => {
    $(".lightbox img", $post).each((_, img) => {
      hide(img);
      observer.observe(img);
    });
  });
}
