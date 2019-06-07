//  Append our CSRF token to AJAX requests when necessary.
export default {
  name: "csrf-token",

  initialize(container) {
    const session = container.lookup("session:main");

    const csrfToken = document
      .querySelector("meta[name=csrf-token]")
      .getAttribute("content");

    // Add a CSRF token to all AJAX requests
    session.set("csrfToken", csrfToken);

    $.ajaxPrefilter((options, originalOptions, xhr) => {
      if (!options.crossDomain) {
        xhr.setRequestHeader("X-CSRF-Token", csrfToken);
      }
    });
  }
};
