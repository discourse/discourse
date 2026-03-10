function trackPageView() {
  const beaconEnabled = !!document.querySelector(
    "meta[name=discourse-enable-beacon-pageview]"
  );

  if (!beaconEnabled) {
    return;
  }

  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";

  if (isErrorPage) {
    return;
  }

  const root =
    document.querySelector("meta[name=discourse-base-uri]")?.content || "";

  const sessionId = document.querySelector(
    "meta[name=discourse-track-view-session-id]"
  )?.content;

  fetch(`${root}/srv/pv`, {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({
      url: window.location.href,
      referrer: document.referrer,
      session_id: sessionId,
      topic_id: null,
    }),
  });
}

document.addEventListener("DOMContentLoaded", trackPageView);
