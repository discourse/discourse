export default Ember.Controller.extend({
  actions: {
    sendInvites() {
      this.send("sendInvites");
    },
    exportUsers() {
      this.send("exportUsers");
    }
  }
});
