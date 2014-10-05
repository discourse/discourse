export default Em.Mixin.create({
  needs: ['modal'],

  flash: function(message, messageClass) {
    this.set('flashMessage', Em.Object.create({
      message: message,
      messageClass: messageClass
    }));
  }
});
