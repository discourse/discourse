/**
  Keep track of when the browser is in focus.
**/
export default {
  name: 'focus-event',

  initialize: function() {

    // Default to true
    Discourse.set('hasFocus', true);

    $(window).focus(function() {
      Discourse.setProperties({hasFocus: true, notify: false});
    }).blur(function() {
      Discourse.set('hasFocus', false);
    });
  }
};
