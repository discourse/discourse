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
        "Discourse-Deferred-Track-View": "true",
      },
    });
  }
});
