import showModal from 'discourse/lib/show-modal';

export default Ember.Mixin.create({
  flash(text, messageClass) {
    this.appEvents.trigger('modal-body:flash', { text, messageClass });
  },

  showModal(...args) {
    return showModal(...args);
  },

  actions: {
    closeModal() {
      this.get('modal').send('closeModal');
    }
  }
});
