export default Ember.Mixin.create({
  isLoadingTriggerables: false,
  triggerables: null,

  fetchTriggerables() {
    this.set("isLoadingTriggerables", true);

    this.store
      .findAll("triggerable")
      .then(results => {
        results.forEach(result => (result.name = I18n.t(result.label)));
        this.set("triggerables", results);
      })
      .finally(() => this.set("isLoadingTriggerables", false));
  }
});
