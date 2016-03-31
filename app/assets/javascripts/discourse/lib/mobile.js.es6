//  An object that is responsible for logic related to mobile devices.
const Mobile = {
  isMobileDevice: false,
  mobileView: false,

  init() {
    const $html = $('html');
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

// Backwards compatibiltity, deprecated
Object.defineProperty(Discourse, 'Mobile', {
  get: function() {
    Ember.warn("DEPRECATION: `Discourse.Mobile` is deprecated, use `this.site.mobileView` instead");
    return Mobile;
  }
});

export default Mobile;
