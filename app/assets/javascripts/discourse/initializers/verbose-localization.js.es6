export default {
  name: 'verbose-localization',
  after: 'inject-objects',

  initialize: function(container) {
    var siteSettings = container.lookup('site-settings:main');
    if (siteSettings.verbose_localization) {
      I18n.enable_verbose_localization();
    }
  }
};
