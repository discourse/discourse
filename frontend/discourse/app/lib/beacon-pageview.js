import getURL from "discourse/lib/get-url";

let _pendingBeaconRequests = 0;

export function hasPendingBeaconRequests() {
  return _pendingBeaconRequests > 0;
}

export function sendBeaconPageview({ sessionId, url, referrer, topicId }) {
  const body = {};
  if (sessionId) {
    body.session_id = sessionId;
  }
  if (url) {
    body.url = url;
  }
  if (referrer) {
    body.referrer = referrer;
  }
  if (topicId) {
    body.topic_id = topicId;
  }

  _pendingBeaconRequests++;
  fetch(getURL("/srv/pv"), {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  }).finally(() => _pendingBeaconRequests--);
}
