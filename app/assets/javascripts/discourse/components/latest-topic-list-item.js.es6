import { showEntrance } from "discourse/components/topic-list-item";

export default Ember.Component.extend({
  tagName: "tr",
  click: showEntrance,
});
