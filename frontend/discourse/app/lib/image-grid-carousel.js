import ImageCarousel from "discourse/components/image-carousel";

const FALLBACK_WIDTH = 1024;
const FALLBACK_HEIGHT = 768;

function parseInfoDimensions(text) {
  if (!text) {
    return null;
  }

  const dimensions = text.trim().split(" ")[0];
  if (!dimensions) {
    return null;
  }

  const [width, height] = dimensions.split(/x|×/).map(Number);
  if (!width || !height) {
    return null;
  }

  return { width, height };
}

function resolveDimensions(anchor, img) {
  const targetWidth = Number(anchor?.dataset.targetWidth || img?.width || 0);
  const targetHeight = Number(anchor?.dataset.targetHeight || img?.height || 0);

  if (targetWidth && targetHeight) {
    return { width: targetWidth, height: targetHeight };
  }

  const infoText = anchor?.querySelector(".informations")?.textContent;
  const infoDimensions = parseInfoDimensions(infoText);
  if (infoDimensions) {
    return infoDimensions;
  }

  const naturalWidth = Number(img?.naturalWidth || 0);
  const naturalHeight = Number(img?.naturalHeight || 0);
  if (naturalWidth && naturalHeight) {
    return { width: naturalWidth, height: naturalHeight };
  }

  return { width: FALLBACK_WIDTH, height: FALLBACK_HEIGHT };
}

function isRenderableImage(img) {
  return (
    !img.classList.contains("thumbnail") &&
    !img.classList.contains("ytp-thumbnail-image") &&
    !img.classList.contains("emoji")
  );
}

function buildCarouselItems(grid) {
  const images = [...grid.querySelectorAll("img")].filter(isRenderableImage);
  const seen = new Set();

  return images
    .map((img) => {
      const wrapper =
        img.closest(".lightbox-wrapper") || img.closest("a.lightbox") || img;
      if (!wrapper || seen.has(wrapper)) {
        return null;
      }

      seen.add(wrapper);
      const anchor = wrapper.matches?.("a.lightbox")
        ? wrapper
        : wrapper.querySelector?.("a.lightbox") || img.closest("a");
      const { width, height } = resolveDimensions(anchor, img);

      return {
        element: wrapper,
        img,
        width,
        height,
      };
    })
    .filter(Boolean);
}

/**
 * Initializes a snap-point carousel for a cooked image grid.
 *
 * @param {HTMLElement} grid
 * @param {Object} helper
 * @returns {boolean}
 */
export default function setupImageGridCarousel(grid, helper) {
  if (!grid || grid.dataset.carouselInitialized) {
    return false;
  }

  if (!helper?.renderGlimmer) {
    return false;
  }

  const items = buildCarouselItems(grid);

  if (!items.length) {
    return false;
  }

  grid.dataset.carouselInitialized = "true";
  grid.classList.add("d-image-grid--carousel");

  const mode = grid.dataset.mode || "focus";

  helper.renderGlimmer(
    grid,
    ImageCarousel,
    {
      items,
      mode,
    },
    { append: false }
  );

  return true;
}
