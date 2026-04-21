import EmbedMode from "discourse/lib/embed-mode";

const THROTTLE_MS = 1000;
const MAX_MESSAGES = 10;

let resizeObserver;
let trailingTimeout;
let lastSentAt = 0;
let messageCount = 0;

function sendHeightMessage(element) {
  if (parent === window) {
    return;
  }
  messageCount++;
  lastSentAt = Date.now();
  parent.postMessage(
    { type: "discourse-resize", height: element.scrollHeight },
    "*"
  );
  if (messageCount >= MAX_MESSAGES) {
    resizeObserver?.disconnect();
    resizeObserver = null;
  }
}

function scheduleHeightMessage(element) {
  if (messageCount >= MAX_MESSAGES) {
    return;
  }
  const elapsed = Date.now() - lastSentAt;
  if (elapsed >= THROTTLE_MS) {
    clearTimeout(trailingTimeout);
    trailingTimeout = null;
    sendHeightMessage(element);
  } else if (!trailingTimeout) {
    trailingTimeout = setTimeout(() => {
      trailingTimeout = null;
      sendHeightMessage(element);
    }, THROTTLE_MS - elapsed);
  }
}

export default {
  initialize() {
    if (!EmbedMode.enabled) {
      return;
    }

    // The body grows with the iframe, so measuring it prevents shrinking.
    // Observe the Ember root element instead to report actual content height.
    const element = document.querySelector("#main");
    if (!element) {
      return;
    }

    resizeObserver = new ResizeObserver(() => scheduleHeightMessage(element));
    resizeObserver.observe(element);
  },

  teardown() {
    resizeObserver?.disconnect();
    resizeObserver = null;
    clearTimeout(trailingTimeout);
    trailingTimeout = null;
    lastSentAt = 0;
    messageCount = 0;
  },
};
