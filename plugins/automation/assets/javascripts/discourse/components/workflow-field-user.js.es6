export default Ember.Component.extend({
  actions: {
    onChange(previously, seletedUsernames) {
      if (seletedUsernames.length) {
        this.onChange(seletedUsernames[0]);
      }
    }
  }
});
