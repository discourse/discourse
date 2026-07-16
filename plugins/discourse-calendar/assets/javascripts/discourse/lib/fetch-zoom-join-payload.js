import { ajax } from "discourse/lib/ajax";

export default function fetchZoomJoinPayload(topicId) {
  const data = { topic_id: topicId };

  // TODO (martin) showzoom is for testing only, remove before merge
  if (new URLSearchParams(window.location.search).get("showzoom")) {
    data.ignore_timeframe = true;
  }

  return ajax("/discourse-calendar/livestream/zoom/signature.json", {
    data,
  });
}
