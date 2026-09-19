import getURL from "discourse/lib/get-url";

// The meeting runs in a window of its own, served by the page this addresses.
// `attempt` is what a retry changes: the frame sets the meeting up as it loads,
// so a new URL is how it is asked to do that again.
export default function zoomFrameUrl({
  topicId,
  attempt = 0,
  ignoreTimeframe,
}) {
  const params = new URLSearchParams({ topic_id: topicId, attempt });

  // TODO (martin) showzoom is for testing only, remove before merge
  if (ignoreTimeframe) {
    params.set("showzoom", "1");
  }

  return getURL(`/discourse-calendar/livestream/zoom/frame?${params}`);
}
