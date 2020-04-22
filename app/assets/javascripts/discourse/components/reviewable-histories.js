import { filterBy } from "@ember/object/computed";
import Component from "@ember/component";
export default Component.extend({
  filteredHistories: filterBy("histories", "created", false)
});
