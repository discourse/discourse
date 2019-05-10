import { fmt } from "discourse/lib/computed";
import computed from "ember-addons/ember-computed-decorators";

export default Ember.Component.extend({
  classNameBindings: [":user-field", "field.field_type"],
  layoutName: fmt("field.field_type", "components/user-fields/%@"),

  @computed
  noneLabel() {
    return "user_fields.none";
  }
});
