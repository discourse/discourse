/**
  A view to display a site setting with edit controls

  @class SiteSettingView
  @extends Discourse.View
  @namespace Discourse
  @module Discourse
**/
Discourse.SiteSettingView = Discourse.View.extend({
  classNameBindings: [':row', ':setting', 'content.overridden'],

  templateName: function() {

    // If we're editing a boolean, return a different template
    if (this.get('content.type') === 'bool') return 'admin/templates/site_settings/setting_bool';

    // If we're editing an enum field, show a dropdown
    if (this.get('content.type') === 'enum' ) return 'admin/templates/site_settings/setting_enum';

    // Default to string editor
    return 'admin/templates/site_settings/setting_string';

  }.property('content.type')

});
