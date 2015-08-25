export default Ember.View.extend({
  focusInput: true,

  _setupModal: function() {
    $('#modal-alert').hide();
    $('#discourse-modal').modal('show');

    // Focus on first element
    if (!Discourse.Mobile.mobileView && this.get('focusInput')) {
      Em.run.schedule('afterRender', () => this.$('input:first').focus());
    }

    const title = this.get('title');
    if (title) {
      this.set('controller.controllers.modal.title', title);
    }
  }.on('didInsertElement'),

  flashMessageChanged: function() {
    const flashMessage = this.get('controller.flashMessage');
    if (flashMessage) {
      const messageClass = flashMessage.get('messageClass') || 'success';
      $('#modal-alert').hide()
                       .removeClass('alert-error', 'alert-success')
                       .addClass("alert alert-" + messageClass).html(flashMessage.get('message'))
                       .fadeIn();
    }
  }.observes('controller.flashMessage')

});
