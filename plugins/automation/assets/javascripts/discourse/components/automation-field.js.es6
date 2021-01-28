import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  placeholdersString: computed("field.placeholders", function () {
    return this.field.placeholders.join(", ");
  }),
});
