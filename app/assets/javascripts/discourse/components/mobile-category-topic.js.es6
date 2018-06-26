import { showEntrance } from "discourse/components/topic-list-item";

export default Ember.Component.extend({
  tagName: "tr",
  classNameBindings: [
    ":category-topic-link",
    "topic.archived",
    "topic.visited"
  ],
  click: showEntrance
});
