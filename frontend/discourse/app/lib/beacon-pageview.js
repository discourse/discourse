import EmbedMode from "discourse/lib/embed-mode";
import getURL from "discourse/lib/get-url";

let _pendingBeaconRequests = 0;

export function hasPendingBeaconRequests() {
  return _pendingBeaconRequests > 0;
}

export function sendBeaconPageview({ sessionId, url, referrer, topicId }) {
  const body = {
    session_id: sessionId,
    url,
    referrer,
  };
  if (topicId) {
    body.topic_id = topicId;
  }
  if (EmbedMode.enabled) {
    body.embed = true;
  }

  _pendingBeaconRequests++;
  fetch(getURL("/srv/pv"), {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }).finally(() => _pendingBeaconRequests--);
}
