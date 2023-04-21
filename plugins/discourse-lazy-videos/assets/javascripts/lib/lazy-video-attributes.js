export default function getVideoAttributes(cooked) {
  if (!cooked.classList.contains("lazy-video-container")) {
    return {};
  }

  const url = cooked.querySelector("a")?.getAttribute("href");
  const img = cooked.querySelector("img");
  const thumbnail = img?.getAttribute("src");
  const dominantColor = img?.dataset?.dominantColor;
  const title = cooked.dataset.videoTitle;
  const providerName = cooked.dataset.providerName;
  const id = cooked.dataset.videoId;

  return { url, thumbnail, title, providerName, id, dominantColor };
}
