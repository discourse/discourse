document.addEventListener("DOMContentLoaded", function () {
  const isErrorPage =
    document.querySelector("meta#discourse-error")?.dataset.discourseError ===
    "true";

  if (!isErrorPage) {
    const root =
      document.querySelector("meta[name=discourse-base-uri]")?.content || "";

    const headers = {
      "Discourse-Deferred-Track-View": "true",
      "Discourse-Deferred-Track-View-Path": window.location.pathname.slice(
        0,
        1024
      ),
    };

    const search = window.location.search;
    if (search && search.length > 1) {
      headers["Discourse-Deferred-Track-View-Query-String"] = search
        .slice(1, 1025)
        .replace(/[\r\n]/g, "");
    }

    if (document.referrer) {
      headers["Discourse-Deferred-Track-View-Referrer"] = document.referrer
        .slice(0, 1024)
        .replace(/[\r\n]/g, "");
    }

    fetch(`${root}/pageview`, {
      method: "POST",
      headers,
    });
  }
});
