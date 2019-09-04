import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  @computed()
  groupChoices() {
    return this.site.get("groups").map(g => {
      return { name: g.name, id: g.id.toString() };
    });
  }
});
