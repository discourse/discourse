import Component from "@ember/component";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import $ from "jquery";

@classNameBindings(":featured-topic")
@attributeBindings("topic.id:data-topic-id")
export default class FeaturedTopic extends Component {
  click(e) {
    if (e.target.closest(".last-posted-at")) {
      this.appEvents.trigger("topic-entrance:show", {
        topic: this.topic,
        position: $(e.target).offset(),
      });
      return false;
    }
  }
}
