import {
  showEntrance,
  navigateToTopic
} from "discourse/components/topic-list-item";

export default Ember.Component.extend({
  attributeBindings: ["topic.id:data-topic-id"],
  classNameBindings: [
    ":latest-topic-list-item",
    "topic.archived",
    "topic.visited"
  ],

  showEntrance,
  navigateToTopic,

  click(e) {
    // for events undefined has a different meaning than false
    if (this.showEntrance(e) === false) {
      return false;
    }

    return this.unhandledRowClick(e, this.get("topic"));
  },

  // Can be overwritten by plugins to handle clicks on other parts of the row
  unhandledRowClick() {}
});
