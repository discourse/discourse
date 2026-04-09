import { withPluginApi } from "discourse/lib/plugin-api";

const REDDIT_EMBED_ORIGINS = [
  "https://embed.reddit.com",
  "https://sh.reddit.com",
];
let redditOneboxResizeListenerAdded = false;

export function decorateGithubOneboxBody(element) {
  const containers = element.querySelectorAll(
    ".onebox.githubcommit .show-more-container, .onebox.githubpullrequest .show-more-container, .onebox.githubissue .show-more-container"
  );

  if (containers.length) {
    element.addEventListener("click", _handleClick, false);

    // cleanup function to remove the event listener while cleaning up the decorations
    return () => element.removeEventListener("click", _handleClick);
  }
}

export function handleRedditOneboxResizeMessage(event, root = document) {
  if (!REDDIT_EMBED_ORIGINS.includes(event.origin) || !event.source) {
    return;
  }

  let messageData = event.data;

  if (typeof messageData === "string") {
    try {
      messageData = JSON.parse(messageData);
    } catch {
      return;
    }
  }

  if (messageData?.type !== "resize.embed") {
    return;
  }

  const height = parseInt(messageData.data, 10);

  if (!height) {
    return;
  }

  root.querySelectorAll("iframe.reddit-onebox").forEach((iframe) => {
    if (iframe.contentWindow === event.source) {
      iframe.setAttribute("height", `${height}`);
    }
  });
}

function ensureRedditOneboxResizeListener() {
  if (redditOneboxResizeListenerAdded || typeof window === "undefined") {
    return;
  }

  window.addEventListener("message", handleRedditOneboxResizeMessage);
  redditOneboxResizeListenerAdded = true;
}

function _handleClick(event) {
  if (!event.target.classList.contains("show-more")) {
    return;
  }

  event.preventDefault();

  const showMoreContainer = event.target.parentNode;
  const bodyContainer = showMoreContainer.parentNode;

  showMoreContainer.classList.add("hidden");
  bodyContainer.querySelector(".excerpt.hidden").classList.remove("hidden");

  return false;
}

export default {
  initialize() {
    ensureRedditOneboxResizeListener();

    withPluginApi((api) => {
      api.decorateCookedElement(decorateGithubOneboxBody);
    });
  },
};
