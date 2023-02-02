import escape from "discourse-common/lib/escape";

export default function buildIFrame(container) {
  const videoId = escape(container.dataset.videoId);
  const providerName = container.dataset.providerName;
  const iframe = document.createElement("iframe");
  iframe.setAttribute("allowFullScreen", "");
  iframe.setAttribute("frameborder", "0");
  iframe.setAttribute("seamless", "seamless");
  iframe.setAttribute(
    "allow",
    "accelerometer; autoplay; encrypted-media; gyroscope; picture-in-picture"
  );

  switch (providerName) {
    case "youtube":
      iframe.setAttribute(
        "src",
        `https://www.youtube.com/embed/${videoId}?autoplay=1`
      );
      break;
    case "vimeo":
      iframe.setAttribute(
        "src",
        `https://player.vimeo.com/video/${videoId}?autoplay=1`
      );
      break;
    case "tiktok":
      iframe.setAttribute("scrolling", "no");
      iframe.setAttribute(
        "sandbox",
        "allow-popups allow-popups-to-escape-sandbox allow-scripts allow-top-navigation allow-same-origin"
      );
      iframe.setAttribute("src", `https://www.tiktok.com/embed/v2/${videoId}`);
      break;
  }
  container.innerHTML = "";
  container.appendChild(iframe);
}
