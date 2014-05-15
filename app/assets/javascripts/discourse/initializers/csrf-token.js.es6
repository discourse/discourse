/**
  Append our CSRF token to AJAX requests when necessary.
**/
export default {
  name: "csrf-token",
  initialize: function() {
    var session = Discourse.Session;

    // Add a CSRF token to all AJAX requests
    session.currentProp('csrfToken', $('meta[name=csrf-token]').attr('content'));

    $.ajaxPrefilter(function(options, originalOptions, xhr) {
      if (!options.crossDomain) {
        xhr.setRequestHeader('X-CSRF-Token', session.currentProp('csrfToken'));
      }
    });
  }
};
