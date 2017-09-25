export default Ember.Mixin.create({
  adminTools: Ember.inject.service(),
  spammerDetails: null,

  onShow() {
    let adminTools = this.get('adminTools');
    let spammerDetails = adminTools.spammerDetails(this.get('model.user'));

    this.setProperties({
      spammerDetails,
      canDeleteSpammer: spammerDetails.canDelete && this.get('model.flaggedForSpam')
    });
  },

  actions: {
    deleteSpammer() {
      let spammerDetails = this.get('spammerDetails');
      this.removeAfter(spammerDetails.deleteUser()).then(() => {
        this.send('closeModal');
      });
    }
  }
});
