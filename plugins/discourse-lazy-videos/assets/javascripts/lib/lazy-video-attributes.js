import { sanitize } from "discourse/lib/text";

export default function getVideoAttributes(cooked) {
  if (!cooked.classList.contains("lazy-video-container")) {
    return {};
  }

  const url = cooked.querySelector("a")?.getAttribute("href");
  const thumbnail = cooked.querySelector("img")?.getAttribute("src");
  const title = sanitize(cooked.dataset.videoTitle);
  const providerName = cooked.dataset.providerName;
  const id = sanitize(cooked.dataset.videoId);

  return { url, thumbnail, title, providerName, id };
}
