import Component from "@ember/component";
import { showEntrance } from "discourse/components/topic-list-item";

export default Component.extend({
  tagName: "tr",
  classNameBindings: [
    ":category-topic-link",
    "topic.archived",
    "topic.visited"
  ],
  click: showEntrance
});
