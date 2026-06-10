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

    if (useBeacon) {
      const body = {
        session_id: trackViewSessionId,
        url: window.location.href,
        referrer: document.referrer.length ? document.referrer : null,
      };
      fetch(`${root}/srv/pv`, {
        method: "POST",
        keepalive: true,
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify(body),
      });
    }

    const engagementPingsEnabled =
      document.querySelector("meta[name=discourse-engagement-ping-enabled]")
        ?.content === "true";

    if (trackViewSessionId && engagementPingsEnabled) {
      let lastPingAt = null;

      const sendPing = () => {
        const now = Date.now();
        if (lastPingAt && now - lastPingAt < 3000) {
          return;
        }
        lastPingAt = now;
        fetch(`${root}/srv/pv`, {
          method: "POST",
          keepalive: true,
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            session_id: trackViewSessionId,
            url: window.location.href,
            engagement: true,
          }),
        });
      };

      const sendPingIfLeaving = () => {
        if (document.visibilityState !== "hidden" && document.hasFocus()) {
          return;
        }
        sendPing();
      };

      document.addEventListener("visibilitychange", sendPingIfLeaving);
      window.addEventListener("blur", sendPingIfLeaving);
      window.addEventListener("pagehide", sendPing);
    }
  }
});
