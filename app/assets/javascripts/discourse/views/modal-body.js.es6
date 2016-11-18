import deprecated from 'discourse-common/lib/deprecated';

export default Ember.View.extend({
  focusInput: true,

  didInsertElement() {
    this._super();

    deprecated('ModalBodyView is deprecated. Use the `d-modal-body` component instead');

    $('#modal-alert').hide();
    $('#discourse-modal').modal('show');
    Ember.run.scheduleOnce('afterRender', this, this._afterFirstRender);

    this.appEvents.on('modal-body:flash', msg => this._flash(msg));
  },

  willDestroyElement() {
    this._super();
    this.appEvents.off('modal-body:flash');
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

  _flash(msg) {
    $('#modal-alert').hide()
                     .removeClass('alert-error', 'alert-success')
                     .addClass(`alert alert-${msg.messageClass || 'success'}`).html(msg.text || '')
                     .fadeIn();
  }
});
