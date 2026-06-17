import { ajax } from "discourse/lib/ajax";

export default function fetchZoomJoinPayload(topicId) {
  return ajax("/discourse-calendar/livestream/zoom/signature.json", {
    data: { topic_id: topicId },
  });
}
