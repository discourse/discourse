const OBSERVER_OPTIONS = {
  rootMargin: "50%" // load images slightly before they're visible
};

// Min size in pixels for consideration for lazy loading
const MINIMUM_SIZE = 150;

const hiddenData = new WeakMap();

const LOADING_DATA =
  "data:image/gif;base64,R0lGODlhAQABAAAAACH5BAEKAAEALAAAAAABAAEAAAICTAEAOw==";

// We hide an image by replacing it with a transparent gif
function hide(image) {
  image.classList.add("d-lazyload");
  image.classList.add("d-lazyload-hidden");

  hiddenData.set(image, {
    src: image.src,
    srcset: image.srcset,
    width: image.width,
    height: image.height
  });
  image.removeAttribute("srcset");

  image.src = image.dataset.smallUpload || LOADING_DATA;
  delete image.dataset.smallUpload;
}

// Restore an image when onscreen
function show(image) {
  let imageData = hiddenData.get(image);

  if (imageData) {
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

    copyImg.src = imageData.src;
    copyImg.srcset = imageData.srcset || copyImg.srcset;

    copyImg.style.position = "absolute";
    copyImg.style.top = 0;
    copyImg.style.left = 0;
    copyImg.style.width = imageData.width;
    copyImg.style.height = imageData.height;

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

  api.decorateCooked(
    $post => {
      $("img", $post).each((_, img) => {
        if (img.width >= MINIMUM_SIZE && img.height >= MINIMUM_SIZE) {
          hide(img);
          observer.observe(img);
        }
      });
    },
    { onlyStream: true }
  );
}
