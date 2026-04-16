import { withPluginApi } from "discourse/lib/plugin-api";

const REDDIT_EMBED_ORIGINS = [
  "https://embed.reddit.com",
  "https://sh.reddit.com",
];
const REDDIT_ONEBOX_RESIZE_LISTENER_STATE = Symbol(
  "reddit-onebox-resize-listener-state"
);

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

function redditOneboxResizeListenerState(eventTarget) {
  eventTarget[REDDIT_ONEBOX_RESIZE_LISTENER_STATE] ||= {
    activeDecorations: 0,
    listenerAdded: false,
  };

  return eventTarget[REDDIT_ONEBOX_RESIZE_LISTENER_STATE];
}

function addRedditOneboxResizeListener(eventTarget) {
  const state = redditOneboxResizeListenerState(eventTarget);
  state.activeDecorations += 1;

  if (!state.listenerAdded) {
    eventTarget.addEventListener("message", handleRedditOneboxResizeMessage);
    state.listenerAdded = true;
  }

  return () => {
    if (state.activeDecorations > 0) {
      state.activeDecorations -= 1;
    }

    if (state.activeDecorations === 0 && state.listenerAdded) {
      eventTarget.removeEventListener(
        "message",
        handleRedditOneboxResizeMessage
      );
      state.listenerAdded = false;
    }
  };
}

export function decorateRedditOneboxes(
  element,
  eventTarget = typeof window === "undefined" ? null : window
) {
  if (!eventTarget || !element.querySelector("iframe.reddit-onebox")) {
    return;
  }

  return addRedditOneboxResizeListener(eventTarget);
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
    withPluginApi((api) => {
      api.decorateCookedElement(decorateGithubOneboxBody);
      api.decorateCookedElement((element) => decorateRedditOneboxes(element));
    });
  },
};
