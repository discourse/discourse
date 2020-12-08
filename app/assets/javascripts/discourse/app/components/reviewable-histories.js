import Component from "@ember/component";
import { filterBy } from "@ember/object/computed";
export default Component.extend({
  filteredHistories: filterBy("histories", "created", false),
});
