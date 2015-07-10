/**
  An object that is responsible for logic related to mobile devices.

  @namespace Discourse
  @module Mobile
**/
Discourse.Mobile = {
  isMobileDevice: false,
  mobileView: false,

  init: function() {
    var $html = $('html');
    this.isMobileDevice = $html.hasClass('mobile-device');
    this.mobileView = $html.hasClass('mobile-view');

    try{
      if (window.location.search.match(/mobile_view=1/)){
        localStorage.mobileView = true;
      }
      if (window.location.search.match(/mobile_view=0/)){
        localStorage.mobileView = false;
      }
      if (localStorage.mobileView) {
        var savedValue = (localStorage.mobileView === 'true');
        if (savedValue !== this.mobileView) {
          this.reloadPage(savedValue);
        }
      }
    } catch(err) {
      // localStorage may be disabled, just skip this
      // you get security errors if it is disabled
    }
  },

  toggleMobileView: function() {
    try{
      if (localStorage) {
        localStorage.mobileView = !this.mobileView;
      }
    } catch(err) {
      // localStorage may be disabled, skip
    }
    this.reloadPage(!this.mobileView);
  },

  reloadPage: function(mobile) {
    window.location.assign(window.location.pathname + '?mobile_view=' + (mobile ? '1' : '0'));
  }
};
