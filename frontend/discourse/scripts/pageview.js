document.addEventListener("DOMContentLoaded", function () {
  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";

  if (!isErrorPage) {
    const root =
      document.querySelector("meta[name=discourse-base-uri]")?.content || "";

    const headers = {
      "Discourse-Deferred-Track-View": "true",
      "Discourse-Deferred-Track-View-Referrer": document.referrer,
    };

    fetch(`${root}/pageview`, {
      method: "POST",
      headers,
    });
  }
});
