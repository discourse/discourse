document.addEventListener("DOMContentLoaded", function () {
  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";

  if (!isErrorPage) {
    const root =
      document.querySelector("meta[name=discourse-base-uri]")?.content || "";

    const trackViewSessionId = document.querySelector(
      "meta[name=discourse-track-view-session-id]"
    )?.content;

    const useBeacon =
      document.querySelector("meta[name=discourse-beacon-pageview-enabled]")
        ?.content === "true";

    if (useBeacon) {
      const body = {};
      if (trackViewSessionId) {
        body.session_id = trackViewSessionId;
        body.url = window.location.href;
        body.referrer = document.referrer.length ? document.referrer : null;
      }
      fetch(`${root}/srv/pv`, {
        method: "POST",
        keepalive: true,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    } else {
      let headers = {
        "Discourse-Track-View-Deferred": "true",
      };

      if (trackViewSessionId) {
        headers = Object.assign(headers, {
          "Discourse-Track-View-Url": window.location.href,
          "Discourse-Track-View-Referrer": document.referrer,
          "Discourse-Track-View-Session-Id": trackViewSessionId,
        });
      }
      fetch(`${root}/pageview`, {
        method: "POST",
        headers,
      });
    }
  }
});
