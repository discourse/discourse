//  Append our CSRF token to AJAX requests when necessary.

let installedFilter = false;

export default {
  name: "csrf-token",
  initialize: function(container) {
    // Add a CSRF token to all AJAX requests
    let session = container.lookup("session:main");
    session.set("csrfToken", $("meta[name=csrf-token]").attr("content"));

    if (!installedFilter) {
      $.ajaxPrefilter(function(options, originalOptions, xhr) {
        if (!options.crossDomain) {
          xhr.setRequestHeader("X-CSRF-Token", session.get("csrfToken"));
        }
      });
      installedFilter = true;
    }
  }
};
