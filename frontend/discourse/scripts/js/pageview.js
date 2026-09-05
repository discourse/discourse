document.addEventListener("DOMContentLoaded", function () {
  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";
  if (isErrorPage) {
    return;
  }

  const trackViewSessionId = document.querySelector(
    "meta[name=discourse-track-view-session-id]"
  )?.content;
  if (!trackViewSessionId) {
    return;
  }

  const root =
    document.querySelector("meta[name=discourse-base-uri]")?.content || "";
  const body = {
    session_id: trackViewSessionId,
    url: window.location.href,
    referrer: document.referrer.length ? document.referrer : null,
    language: navigator.language,
  };

  fetch(`${root}/srv/pv`, {
    method: "POST",
    keepalive: true,
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify(body),
  });
});
