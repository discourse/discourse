import ModalFunctionality from "discourse/mixins/modal-functionality";

export default Ember.Controller.extend(ModalFunctionality, {
  showGoogleSearch: function() {
    return !Discourse.SiteSettings.login_required;
  }.property()
});
