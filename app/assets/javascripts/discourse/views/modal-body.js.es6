import { observes } from "ember-addons/ember-computed-decorators";
import deprecated from 'discourse-common/lib/deprecated';

export default Ember.View.extend({
  focusInput: true,

  didInsertElement() {
    this._super();

    deprecated('ModalBodyView is deprecated. Use the `d-modal-body` component instead');

    $('#modal-alert').hide();
    $('#discourse-modal').modal('show');
    Ember.run.scheduleOnce('afterRender', this, this._afterFirstRender);
  },

  _afterFirstRender() {
    if (!this.site.mobileView && this.get('focusInput')) {
      this.$('input:first').focus();
    }

    const title = this.get('title');
    if (title) {
      this.set('controller.modal.title', title);
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
