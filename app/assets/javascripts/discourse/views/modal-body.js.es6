import { observes, on } from "ember-addons/ember-computed-decorators";

export default Ember.View.extend({
  focusInput: true,

  @on("didInsertElement")
  _setupModal() {
    $('#modal-alert').hide();
    $('#discourse-modal').modal('show');

    // Focus on first element
    if (!this.site.mobileView && this.get('focusInput')) {
      Em.run.schedule('afterRender', () => this.$('input:first').focus());
    }

    const title = this.get('title');
    if (title) {
      this.set('controller.controllers.modal.title', title);
    }
  },

  @observes("controller.flashMessage")
  flashMessageChanged() {
    const flashMessage = this.get('controller.flashMessage');
    if (flashMessage) {
      const messageClass = flashMessage.get('messageClass') || 'success';
      $('#modal-alert').hide()
                       .removeClass('alert-error', 'alert-success')
                       .addClass("alert alert-" + messageClass).html(flashMessage.get('message'))
                       .fadeIn();
    }
  }

});
