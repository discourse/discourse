import Component from "@ember/component";
import { htmlSafe } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import $ from "jquery";
import TopicPostBadges from "discourse/components/topic-post-badges";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import TopicStatus from "./topic-status";

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

  <template>
    <TopicStatus @topic={{this.topic}} @disableActions={{true}} />
    <a href={{this.topic.lastUnreadUrl}} class="title">{{htmlSafe
        this.topic.fancyTitle
      }}</a>
    <TopicPostBadges
      @unreadPosts={{this.topic.unread_posts}}
      @unseen={{this.topic.unseen}}
      @url={{this.topic.lastUnreadUrl}}
    />

    <a href={{this.topic.lastPostUrl}} class="last-posted-at">{{ageWithTooltip
        this.topic.last_posted_at
      }}</a>
  </template>
}
