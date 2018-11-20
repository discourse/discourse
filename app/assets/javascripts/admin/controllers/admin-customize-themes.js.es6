import { default as computed } from "ember-addons/ember-computed-decorators";

export default Ember.Controller.extend({
  @computed("model", "model.@each", "model.@each.component")
  fullThemes(themes) {
    return _.sortBy(themes.filter(t => !t.get("component")), t => {
      return [
        !t.get("default"),
        !t.get("user_selectable"),
        t.get("name").toLowerCase()
      ];
    });
  },

  @computed("model", "model.@each", "model.@each.component")
  childThemes(themes) {
    return themes.filter(t => t.get("component"));
  }
});
