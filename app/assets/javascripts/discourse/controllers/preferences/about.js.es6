import ObjectController from 'discourse/controllers/object';

/**
  This controller supports actions related to updating your "About Me" bio

  @class PreferencesAboutController
  @extends ObjectController
  @namespace Discourse
  @module Discourse
**/
export default ObjectController.extend({
  saving: false,

  saveButtonText: function() {
    if (this.get('saving')) return I18n.t("saving");
    return I18n.t("user.change");
  }.property('saving')

});
