import { later } from "@ember/runloop";
import PostUpdater from "./updaters/post-updater";

const PROGRESS_INTERVAL = 40;
const GIVE_UP_INTERVAL = 600000; // 10 minutes which is our max thinking time for now
export const MIN_LETTERS_PER_INTERVAL = 6;
const MAX_FLUSH_TIME = 800;

let progressTimer = null;

/**
 * Finds the last non-empty child element or text node of a given DOM element.
 * Iterates backward through the element's child nodes and skips over empty text nodes.
 *
 * @param {HTMLElement} element - The DOM element to inspect.
 * @returns {Node} - The last non-empty child node or null if none found.
 */
function lastNonEmptyChild(element) {
  let lastChild = element.lastChild;
  while (
    lastChild &&
    lastChild.nodeType === Node.TEXT_NODE &&
    !/\S/.test(lastChild.textContent)
  ) {
    lastChild = lastChild.previousSibling;
  }
  return lastChild;
}

/**
 * Adds a progress dot (a span element with a "progress-dot" class) at the end of the
 * last non-empty block within a given DOM element. This is used to visually indicate
 * progress while content is being streamed.
 *
 * @param {HTMLElement} element - The DOM element to which the progress dot will be added.
 */
export function addProgressDot(element) {
  let lastBlock = element;

  while (true) {
    let lastChild = lastNonEmptyChild(lastBlock);
    if (!lastChild) {
      break;
    }

    if (lastChild.nodeType === Node.ELEMENT_NODE) {
      lastBlock = lastChild;
    } else {
      break;
    }
  }

  const dotElement = document.createElement("span");
  dotElement.classList.add("progress-dot");
  lastBlock.appendChild(dotElement);
}

/**
 * Applies progress to a streaming operation, updating the raw and cooked text,
 * handling progress dots, and stopping streaming when complete.
 *
 * @param {Object} status - The current streaming status object.
 * @param {Object} updater - An instance of a stream updater (e.g., PostUpdater or SummaryUpdater).
 * @returns {Promise<boolean>} - Resolves to true if streaming is complete, otherwise false.
 */
export async function applyProgress(status, updater) {
  status.startTime = status.startTime || Date.now();

  if (Date.now() - status.startTime > GIVE_UP_INTERVAL) {
    updater.streaming = false;
    return true;
  }

  if (!updater.element) {
    // wait till later
    return false;
  }

  const oldRaw = updater.raw;
  if (status.raw === oldRaw && !status.done) {
    const hasProgressDot = updater.element.querySelector(".progress-dot");
    if (hasProgressDot) {
      return false;
    }
  }

  if (status.raw !== undefined) {
    let newRaw = status.raw;

    if (!status.done) {
      // rush update if we have a </details> tag (function call)
      if (oldRaw.length === 0 && newRaw.indexOf("</details>") !== -1) {
        newRaw = status.raw;
      } else {
        const diff = newRaw.length - oldRaw.length;

        // progress interval is 40ms
        // by default we add 6 letters per interval
        // but ... we want to be done in MAX_FLUSH_TIME
        let letters = Math.floor(diff / (MAX_FLUSH_TIME / PROGRESS_INTERVAL));
        if (letters < MIN_LETTERS_PER_INTERVAL) {
          letters = MIN_LETTERS_PER_INTERVAL;
        }

        newRaw = status.raw.substring(0, oldRaw.length + letters);
      }
    }

    await updater.setRaw(newRaw, status.done);
  }

  if (status.done) {
    if (status.cooked) {
      await updater.setCooked(status.cooked);
    }
    updater.streaming = false;
  }

  return status.done;
}

/**
 * Handles progress updates for a post stream by applying the streaming status of
 * each post and updating its content accordingly. This function ensures that progress
 * is tracked and handled for multiple posts simultaneously.
 *
 * @param {Object} postStream - The post stream object containing the posts to be updated.
 * @returns {Promise<boolean>} - Resolves to true if polling should continue, otherwise false.
 */
async function handleProgress(postStream) {
  const status = postStream.aiStreamingStatus;

  let keepPolling = false;

  const promises = Object.keys(status).map(async (postId) => {
    let postStatus = status[postId];

    const postUpdater = new PostUpdater(postStream, postStatus.post_id);
    const done = await applyProgress(postStatus, postUpdater);

    if (done) {
      delete status[postId];
    } else {
      keepPolling = true;
    }
  });

  await Promise.all(promises);
  return keepPolling;
}

/**
 * Ensures that progress for a post stream is being updated. It starts a progress timer
 * if one is not already active, and continues polling for progress updates at regular intervals.
 *
 * @param {Object} postStream - The post stream object containing the posts to be updated.
 */
function ensureProgress(postStream) {
  if (!progressTimer) {
    progressTimer = later(async () => {
      const keepPolling = await handleProgress(postStream);

      progressTimer = null;

      if (keepPolling) {
        ensureProgress(postStream);
      }
    }, PROGRESS_INTERVAL);
  }
}

/**
 * Streams the raw text for a post by tracking its status and applying progress updates.
 * If streaming is already in progress, this function ensures it continues to update the content.
 *
 * @param {Object} postStream - The post stream object containing the post to be updated.
 * @param {Object} data - The data object containing raw and cooked content of the post.
 */
export function streamPostText(postStream, data) {
  if (data.noop) {
    return;
  }

  let status = (postStream.aiStreamingStatus =
    postStream.aiStreamingStatus || {});
  status[data.post_id] = data;
  ensureProgress(postStream);
}

/**
 * A generalized function to handle streaming of content using any specified updater class.
 * It applies progress updates to the content (raw and cooked) based on the given data.
 * Use this function to stream content for Glimmer components.
 *
 * @param {Function} updaterClass - The updater class to be used for streaming (e.g., PostUpdater, SummaryUpdater).
 * @param {Object} data - The data object containing the content to be streamed.
 * @param {Object} context - Additional context required for the updater (typically the context of the Ember component).
 */
export default function streamUpdaterText(updaterClass, data, context) {
  const updaterInstance = new updaterClass(data, context);

  if (!progressTimer) {
    progressTimer = later(async () => {
      await applyProgress(data, updaterInstance);

      progressTimer = null;

      if (!data.done) {
        await applyProgress(data, updaterInstance);
      }
    }, PROGRESS_INTERVAL);
  }
}
