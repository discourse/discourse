export async function createDownloadLink(lightboxItem) {
  try {
    const link = document.createElement("a");
    link.href = lightboxItem.downloadURL;
    link.download = lightboxItem.title;
    link.click();
  } catch (error) {
    // eslint-disable-next-line no-console
    console.error(error);
  }
}
