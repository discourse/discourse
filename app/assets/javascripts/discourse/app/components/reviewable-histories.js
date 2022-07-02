import Component from "@ember/component";
import { filterBy } from "@ember/object/computed";
export default Component.extend({
  tagName: "",
  filteredHistories: filterBy("histories", "created", false)
});
