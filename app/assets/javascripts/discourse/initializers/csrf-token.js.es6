//  Append our CSRF token to AJAX requests when necessary.

let installed = false;
let callbacks = $.Callbacks();

export default {
  name: "csrf-token",
  initialize(container) {
    // Add a CSRF token to all AJAX requests
    let session = container.lookup("session:main");
    session.set("csrfToken", $("meta[name=csrf-token]").attr("content"));

    if (!installed) {
      $.ajaxPrefilter(callbacks.fire);
      installed = true;
    }

    callbacks.add(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader("X-CSRF-Token", session.get("csrfToken"));
      }
    });
  },

  teardown() {
    callbacks.empty();
  }
};
