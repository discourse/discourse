import getURL from "discourse/lib/get-url";

// Repeats are harmless (the server keeps the latest receipt per pageview),
// so the throttle only bounds how fast a tab-flapper can send.
const RESEND_THROTTLE_MS = 3000;

let currentSessionId = null;
let currentUrl = null;
let lastSentAt = null;
let listening = false;

export function trackPageForExitPing({ sessionId, url }) {
  if (!sessionId || !url || !pingsEnabled()) {
    return;
  }

  currentSessionId = sessionId;
  currentUrl = url;
  lastSentAt = null;

  if (!listening) {
    document.addEventListener("visibilitychange", sendPingIfLeaving);
    window.addEventListener("blur", sendPingIfLeaving);
    window.addEventListener("pagehide", sendPing);
    listening = true;
  }
}

export function resetExitPingTracking() {
  document.removeEventListener("visibilitychange", sendPingIfLeaving);
  window.removeEventListener("blur", sendPingIfLeaving);
  window.removeEventListener("pagehide", sendPing);
  currentSessionId = null;
  currentUrl = null;
  lastSentAt = null;
  listening = false;
}

// The server discards pings unless persist_browser_pageview_events is on,
// so a site that only counts pageviews should not pay a request per leave.
function pingsEnabled() {
  return (
    document.querySelector("meta[name=discourse-engagement-ping-enabled]")
      ?.content === "true"
  );
}

function sendPingIfLeaving() {
  // Check the actual state rather than trusting the event type: focus moving
  // into an iframe fires `blur` while the user is still engaged, and bfcache
  // restores fire `visibilitychange` back to visible.
  if (document.visibilityState !== "hidden" && document.hasFocus()) {
    return;
  }

  sendPing();
}

// pagehide sends unconditionally: it is the only leave signal older iOS
// Safari fires, and on other browsers the throttle absorbs the duplicate.
function sendPing() {
  if (!currentSessionId) {
    return;
  }

  const now = Date.now();
  if (lastSentAt && now - lastSentAt < RESEND_THROTTLE_MS) {
    return;
  }
  lastSentAt = now;

  fetch(getURL("/srv/pv"), {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      session_id: currentSessionId,
      url: currentUrl,
      engagement: true,
    }),
  });
}
