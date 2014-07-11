/**
  A view to display a site setting with edit controls

  @class SiteSettingView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteSettingView = Discourse.View.extend(Discourse.ScrollTop, {
  classNameBindings: [':row', ':setting', 'content.overridden'],

  templateName: function() {
    // If we're editing a boolean, show a checkbox
    if (this.get('content.type') === 'bool') return 'admin/templates/site_settings/setting_bool';

    // If we're editing an enum field, show a dropdown
    if (this.get('content.type') === 'enum' ) return 'admin/templates/site_settings/setting_enum';

    // If we're editing a list, show a list editor
    if (this.get('content.type') === 'list' ) return 'admin/templates/site_settings/setting_list';

    // Default to string editor
    return 'admin/templates/site_settings/setting_string';

  }.property('content.type'),

  didInsertElement: function() {
    var self = this;
    this._super();
    Em.run.schedule('afterRender', function() {
      self.$('.input-setting-string').keydown(function(e) {
        if (e.keyCode === 13) { // enter key
          var setting = self.get('content');
          if (setting.get('dirty')) {
            setting.save();
          }
        }
      });
    });
  }

});
