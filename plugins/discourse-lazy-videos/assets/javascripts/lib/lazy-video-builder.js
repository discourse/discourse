import escape from "discourse-common/lib/escape";

export default function buildLazyVideo(container, callback) {
  const titleText = escape(container.dataset.videoTitle);
  const providerName = container.dataset.providerName;

  const thumbnailImg = container.querySelector("img");
  const thumbnail = document.createElement("div");
  thumbnail.classList.add("video-thumbnail");
  thumbnail.classList.add(providerName);
  thumbnail.setAttribute("tabIndex", "0");
  thumbnail.appendChild(thumbnailImg);

  const icon = document.createElement("div");
  icon.classList.add("icon");
  icon.classList.add(`${providerName}-icon`);
  thumbnail.appendChild(icon);

  const link = container.querySelector("a");
  const linkUrl = link.getAttribute("href");

  const titleContainer = document.createElement("div");
  const titleWrapper = document.createElement("div");
  const titleLink = document.createElement("a");

  titleContainer.classList.add("title-container");
  titleWrapper.classList.add("title-wrapper");

  titleLink.classList.add("title-link");
  titleLink.setAttribute("href", linkUrl);
  titleLink.setAttribute("target", "_blank");

  titleLink.innerText = titleText;
  titleLink.setAttribute("title", titleText);
  titleWrapper.appendChild(titleLink);
  titleContainer.appendChild(titleWrapper);

  link.replaceWith(thumbnail);
  container.appendChild(titleContainer);

  thumbnail.addEventListener("click", (e) => {
    e.preventDefault();
    callback.loadEmbed();
  });
  thumbnail.addEventListener("keypress", (e) => {
    if (e.key === "Enter") {
      e.preventDefault();
      callback.loadEmbed();
    }
  });
}
