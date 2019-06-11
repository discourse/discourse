//  Append our CSRF token to AJAX requests when necessary.
export default {
  name: "csrf-token",
  initialize(container) {
    const session = container.lookup("session:main");
    const csrfToken = $("meta[name=csrf-token]").attr("content");

    // Add a CSRF token to all AJAX requests
    session.set("csrfToken", csrfToken);

    $.ajaxPrefilter(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader("X-CSRF-Token", csrfToken);
      }
    });
  }
};
