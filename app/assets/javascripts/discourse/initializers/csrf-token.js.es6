//  Append our CSRF token to AJAX requests when necessary.
let _crsfCallbacks;

export default {
  name: "csrf-token",

  initialize(container) {
    const session = container.lookup("session:main");
    _crsfCallbacks = $.Callbacks();

    // Add a CSRF token to all AJAX requests
    session.set("csrfToken", $("meta[name=csrf-token]").attr("content"));

    _crsfCallbacks.add(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader("X-CSRF-Token", session.csrfToken);
      }
    });

    $.ajaxPrefilter(_crsfCallbacks);
  }
};

export function resetCsrfCallbacks() {
  _crsfCallbacks.empty();
  _crsfCallbacks = null;
}
