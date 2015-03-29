/**
  Initializes the `Discourse.Mobile` helper object.
**/
export default {
  name: 'mobile',
  after: 'inject-objects',

  initialize: function(container) {
    Discourse.Mobile.init();
    var site = container.lookup('site:main');
    site.set('mobileView', Discourse.Mobile.mobileView);
  }
};

