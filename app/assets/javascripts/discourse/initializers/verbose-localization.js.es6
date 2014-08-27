export default {
  name: 'verbose-localization',
  initialize: function() {

    if(Discourse.SiteSettings.verbose_localization){
      I18n.enable_verbose_localization();
    }
  }
};
