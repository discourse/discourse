export default Em.Mixin.create({
  flashMessage: null,

  needs: ['modal'],

  flash(message, messageClass) {
    this.set('flashMessage', Em.Object.create({ message, messageClass }));
  }
});
