/*global Modernizr:true*/

/**
  Initializes an object that lets us know about our capabilities.
**/
export default {
  name: "sniff-capabilities",
  initialize: function(container, application) {
    var $html = $('html'),
        touch = $html.hasClass('touch') || (Modernizr.prefixed("MaxTouchPoints", navigator) > 1),
        caps = Ember.Object.create();

    // Store the touch ability in our capabilities object
    caps.set('touch', touch);
    $html.addClass(touch ? 'discourse-touch' : 'discourse-no-touch');

    // Detect Android
    if (navigator) {
      var ua = navigator.userAgent;
      caps.set('android', ua && ua.indexOf('Android') !== -1);
    }

    // We consider high res a device with 1280 horizontal pixels. High DPI tablets like
    // iPads should report as 1024.
    caps.set('highRes', window.screen.width >= 1280);

    // Inject it
    application.register('capabilities:main', caps, { instantiate: false });
    application.inject('view', 'capabilities', 'capabilities:main');
    application.inject('controller', 'capabilities', 'capabilities:main');
    application.inject('component', 'capabilities', 'capabilities:main');
  }
};
