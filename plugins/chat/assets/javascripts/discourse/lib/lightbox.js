import lightbox from "discourse/lib/lightbox";

export default function loadLightbox(images, siteSettings) {
  if (!images || images.length === 0) {
    return;
  }

  lightbox(images, siteSettings);
}
