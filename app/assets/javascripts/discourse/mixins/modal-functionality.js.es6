export default Ember.Mixin.create({
  flash(text, messageClass) {
    this.appEvents.trigger('modal-body:flash', { text, messageClass });
  }
});
