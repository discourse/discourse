export default async function lightbox(imagesSelectorOrElements) {
  const [{ default: PhotoSwipeLightbox }, { default: PhotoSwipe }] =
    await Promise.all([import("photoswipe/lightbox"), import("photoswipe")]);

  const elements =
    typeof imagesSelectorOrElements === "string"
      ? document.querySelectorAll(imagesSelectorOrElements)
      : imagesSelectorOrElements;

  const items = Array.from(elements).map((el) => {
    const src = el.dataset.largeSrc || el.src;
    const width = parseInt(el.getAttribute("width"), 10) || 0;
    const height = parseInt(el.getAttribute("height"), 10) || 0;
    return { src, w: width, h: height, element: el };
  });

  const pswpLightbox = new PhotoSwipeLightbox({
    dataSource: items,
    pswpModule: PhotoSwipe,
    wheelToZoom: true,
    showHideAnimationType: "fade",
  });

  pswpLightbox.addFilter("itemData", (itemData) => {
    if (!itemData.src && itemData.element) {
      itemData.src = itemData.element.dataset.largeSrc || itemData.element.src;
    }
    return itemData;
  });

  pswpLightbox.init();
}
