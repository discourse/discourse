export default Ember.Mixin.create({
  flashMessage: null,

  flash(message, messageClass) {
    this.set('flashMessage', Em.Object.create({ message, messageClass }));
  }
});
