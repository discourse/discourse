import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  tagName: "",

  dateObject: computed("field.metadata.date", function() {
    return moment(this.field.metadata.date);
  })
});
