document.addEventListener("DOMContentLoaded", function () {
  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";

  if (!isErrorPage) {
    const root =
      document.querySelector("meta[name=discourse-base-uri]")?.content || "";

    fetch(`${root}/pageview`, {
      method: "POST",
      headers: {
        "Discourse-Track-View-Deferred": "true",
        "Discourse-Track-View-Url": window.location.href,
        "Discourse-Track-View-Referrer": document.referrer,
        "Discourse-Track-View-Session-Id": document.querySelector(
          "meta[name=discourse-track-view-session-id]"
        )?.content,
      },
    });
  }
});
