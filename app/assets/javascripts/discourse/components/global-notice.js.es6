import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  rerenderTriggers: ['site.isReadOnly'],

  renderString: function(buffer) {
    let notices = [];

    if (this.site.get("isReadOnly")) {
      notices.push([I18n.t("read_only_mode.enabled"), 'alert-read-only']);
    }

    if (this.siteSettings.disable_emails) {
      notices.push([I18n.t("emails_are_disabled"), 'alert-emails-disabled']);
    }

    if (!_.isEmpty(this.siteSettings.global_notice)) {
      notices.push([this.siteSettings.global_notice, 'alert-global-notice']);
    }

    if (notices.length > 0) {
      buffer.push(_.map(notices, n => "<div class='row'><div class='alert alert-info " + n[1] + "'>" + n[0] + "</div></div>").join(""));
    }
  }
});
