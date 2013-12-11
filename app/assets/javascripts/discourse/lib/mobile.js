/**
  An object that is responsible for logic related to mobile devices.

  @namespace Discourse
  @module Mobile
**/
Discourse.Mobile = {

  mobileView: false,

  init: function() {
    var $html = $('html');
    this.mobileView = $html.hasClass('mobile-view');
  },

  toggleMobileView: function() {
    if (localStorage) {
      localStorage.mobileView = !this.mobileView;
    }
    window.location.reload();
  }

};
