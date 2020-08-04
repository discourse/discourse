const OBSERVER_OPTIONS = {
  rootMargin: "66%" // load images slightly before they're visible
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
    height: image.height,
    className: image.className
  });

  image.src = image.dataset.smallUpload || LOADING_DATA;
  image.removeAttribute("srcset");

  image.removeAttribute("data-small-upload");
}

// Restore an image when onscreen
function show(image) {
  let imageData = hiddenData.get(image);

  if (imageData) {
    const copyImg = new Image();
    copyImg.onload = () => {
      if (copyImg.srcset) {
        image.srcset = copyImg.srcset;
      }
      image.src = copyImg.src;
      image.classList.remove("d-lazyload-hidden");

      if (image.onload) {
        // don't bother fighting with existing handler
        // this can mean a slight flash on mobile
        image.parentNode.removeChild(copyImg);
      } else {
        image.onload = () => {
          image.parentNode.removeChild(copyImg);
          image.onload = null;
        };
      }

      copyImg.onload = null;
    };

    if (imageData.srcset) {
      copyImg.srcset = imageData.srcset;
    }

    copyImg.src = imageData.src;

    // width of image may not match, use computed style which
    // is the actual size of the image
    const computedStyle = window.getComputedStyle(image);
    const actualWidth = parseInt(computedStyle.width, 10);
    const actualHeight = parseInt(computedStyle.height, 10);

    copyImg.style.position = "absolute";
    copyImg.style.top = `${image.offsetTop}px`;
    copyImg.style.left = `${image.offsetLeft}px`;
    copyImg.style.width = `${actualWidth}px`;
    copyImg.style.height = `${actualHeight}px`;

    copyImg.className = imageData.className;

    // insert after the current element so styling still will
    // apply to original image firstChild selectors
    image.parentNode.insertBefore(copyImg, image.nextSibling);
  } else {
    image.classList.remove("d-lazyload-hidden");
  }
}

function forEachImage(post, callback) {
  post.querySelectorAll("img").forEach(img => {
    if (img.width >= MINIMUM_SIZE && img.height >= MINIMUM_SIZE) {
      callback(img);
    }
  });
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

  api.decorateCookedElement(post => forEachImage(post, img => hide(img)), {
    onlyStream: true,
    id: "discourse-lazy-load"
  });

  // IntersectionObserver.observe must be called after the cooked
  // content is adopted by the document element in chrome
  // https://bugs.chromium.org/p/chromium/issues/detail?id=1073469
  api.decorateCookedElement(
    post => forEachImage(post, img => observer.observe(img)),
    {
      onlyStream: true,
      id: "discourse-lazy-load-after-adopt",
      afterAdopt: true
    }
  );
}
