import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  date: computed("metadata.execute_at", function () {
    return moment(this.metadata.execute_at);
  }),
});
