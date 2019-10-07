export default Ember.Mixin.create({
  isLoadingPlannables: false,
  plannables: null,

  fetchPlannables() {
    this.set("isLoadingPlannables", true);

    return this.store
      .findAll("plannable")
      .then(results => {
        results.forEach(result => (result.name = I18n.t(result.label)));
        this.set("plannables", results);
        return results;
      })
      .finally(() => this.set("isLoadingPlannables", false));
  }
});
