export async function preloadItemImages(lightboxItem) {
  if (!lightboxItem) {
    return;
  }

  if (lightboxItem.isLoaded && !lightboxItem.hasLoadingError) {
    return lightboxItem;
  }

  const fullsizeImage = new Image();
  const smallImage = new Image();

  const fullsizeImagePromise = new Promise((resolve, reject) => {
    fullsizeImage.onload = resolve;
    fullsizeImage.onerror = reject;
    fullsizeImage.src = lightboxItem.fullsizeURL;
  });

  const smallImagePromise = new Promise((resolve, reject) => {
    smallImage.onload = resolve;
    smallImage.onerror = reject;
    smallImage.src = lightboxItem.smallURL;
  });

  try {
    await Promise.all([fullsizeImagePromise, smallImagePromise]);

    lightboxItem = {
      ...lightboxItem,
      isLoaded: true,
      hasLoadingError: false,
      width: fullsizeImage.naturalWidth,
      height: fullsizeImage.naturalHeight,
      aspectRatio:
        lightboxItem.aspectRatio ||
        `${smallImage.naturalWidth} / ${smallImage.naturalHeight}`,
      canZoom:
        fullsizeImage.naturalWidth > window.innerWidth ||
        fullsizeImage.naturalHeight > window.innerHeight,
    };
  } catch {
    lightboxItem.hasLoadingError = true;
    // eslint-disable-next-line no-console
    console.error(
      `Failed to load lightbox image ${lightboxItem.index}: ${lightboxItem.fullsizeURL}`
    );
  }

  return lightboxItem;
}
