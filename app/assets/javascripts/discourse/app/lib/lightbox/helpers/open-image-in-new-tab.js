export async function openImageInNewTab(lightboxItem) {
  try {
    window.open(lightboxItem.fullsizeURL, "_blank");
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
}
