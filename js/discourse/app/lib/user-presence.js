import { isTesting } from "discourse/lib/environment";

const callbacks = [];

const DEFAULT_USER_UNSEEN_MS = 60000;
const DEFAULT_BROWSER_HIDDEN_MS = 0;

let browserHiddenAt = null;
let lastUserActivity = Date.now();
let userSeenJustNow = false;

let callbackWaitingForPresence = false;

let testPresence = true;

// Check whether the document is currently visible, and the user is actively using the site
// Will return false if the browser went into the background more than `browserHiddenTime` milliseconds ago
// Will also return false if there has been no user activity for more than `userUnseenTime` milliseconds
// Otherwise, will return true
export default function userPresent({
  browserHiddenTime = DEFAULT_BROWSER_HIDDEN_MS,
  userUnseenTime = DEFAULT_USER_UNSEEN_MS,
} = {}) {
  if (isTesting()) {
    return testPresence;
  }

  if (browserHiddenAt) {
    const timeSinceBrowserHidden = Date.now() - browserHiddenAt;
    if (timeSinceBrowserHidden >= browserHiddenTime) {
      return false;
    }
  }

  const timeSinceUserActivity = Date.now() - lastUserActivity;
  if (timeSinceUserActivity >= userUnseenTime) {
    return false;
  }

  return true;
}

// Register a callback to be triggered when the value of `userPresent()` changes.
// userUnseenTime and browserHiddenTime work the same as for `userPresent()`
// 'not present' callbacks may lag by up to 10s, depending on the reason
// 'now present' callbacks should be almost instantaneous
export function onPresenceChange({
  userUnseenTime = DEFAULT_USER_UNSEEN_MS,
  browserHiddenTime = DEFAULT_BROWSER_HIDDEN_MS,
  callback,
} = {}) {
  if (userUnseenTime < DEFAULT_USER_UNSEEN_MS) {
    throw `userUnseenTime must be at least ${DEFAULT_USER_UNSEEN_MS}`;
  }
  callbacks.push({
    userUnseenTime,
    browserHiddenTime,
    lastState: true,
    callback,
  });
}

export function removeOnPresenceChange(callback) {
  const i = callbacks.findIndex((c) => c.callback === callback);
  callbacks.splice(i, 1);
}

function processChanges() {
  const browserHidden = document.hidden;
  if (!!browserHiddenAt !== browserHidden) {
    browserHiddenAt = browserHidden ? Date.now() : null;
  }

  if (userSeenJustNow) {
    lastUserActivity = Date.now();
    userSeenJustNow = false;
  }

  callbackWaitingForPresence = false;
  for (const callback of callbacks) {
    const currentState = userPresent({
      userUnseenTime: callback.userUnseenTime,
      browserHiddenTime: callback.browserHiddenTime,
    });

    if (callback.lastState !== currentState) {
      try {
        callback.callback(currentState);
      } finally {
        callback.lastState = currentState;
      }
    }

    if (!currentState) {
      callbackWaitingForPresence = true;
    }
  }
}

export function seenUser() {
  userSeenJustNow = true;
  if (callbackWaitingForPresence) {
    processChanges();
  }
}

export function visibilityChanged() {
  if (document.hidden) {
    processChanges();
  } else {
    seenUser();
  }
}

export function setTestPresence(value) {
  if (!isTesting()) {
    throw "Only available in test mode";
  }
  testPresence = value;
}

export function clearPresenceCallbacks() {
  callbacks.length = 0;
}

if (!isTesting()) {
  // Some of these events occur very frequently. Therefore seenUser() is as fast as possible.
  document.addEventListener("touchmove", seenUser, { passive: true });
  document.addEventListener("click", seenUser, { passive: true });
  window.addEventListener("scroll", seenUser, { passive: true });
  window.addEventListener("focus", seenUser, { passive: true });

  document.addEventListener("visibilitychange", visibilityChanged, {
    passive: true,
  });

  setInterval(processChanges, 10000);
}
