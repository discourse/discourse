export default Em.Mixin.create({
  flashMessage: null,

  needs: ['modal'],

  flash: function(message, messageClass) {
    this.set('flashMessage', Em.Object.create({ message, messageClass }));
  }
});
