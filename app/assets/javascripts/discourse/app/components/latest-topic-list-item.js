import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import {
  navigateToTopic,
  showEntrance,
} from "discourse/components/topic-list-item";
import discourseComputed from "discourse/lib/decorators";

@attributeBindings("topic.id:data-topic-id")
@classNameBindings(":latest-topic-list-item", "unboundClassNames")
export default class LatestTopicListItem extends Component {
  showEntrance = showEntrance;
  navigateToTopic = navigateToTopic;

  click(e) {
    // for events undefined has a different meaning than false
    if (this.showEntrance(e) === false) {
      return false;
    }

    return this.unhandledRowClick(e, this.topic);
  }

  // Can be overwritten by plugins to handle clicks on other parts of the row
  unhandledRowClick() {}

  @discourseComputed("topic")
  unboundClassNames(topic) {
    let classes = [];

    if (topic.get("category")) {
      classes.push("category-" + topic.get("category.fullSlug"));
    }

    if (topic.get("tags")) {
      topic.get("tags").forEach((tagName) => classes.push("tag-" + tagName));
    }

    ["liked", "archived", "bookmarked", "pinned", "closed", "visited"].forEach(
      (name) => {
        if (topic.get(name)) {
          classes.push(name);
        }
      }
    );

    return classes.join(" ");
  }
}
