export default Ember.Component.extend({
  didInsertElement() {
    this._super(...arguments);
    Ember.run.next(null, () => {
      const $this = this.$();

      if ($this) {
        $this.find("hr").remove();
        $this.ellipsis();
      }
    });
  }
});
