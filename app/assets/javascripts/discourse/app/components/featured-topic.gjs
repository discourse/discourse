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
{{raw "topic-status" topic=this.topic}}
<a href={{this.topic.lastUnreadUrl}} class="title">{{html-safe
    this.topic.fancyTitle
  }}</a>
<TopicPostBadges
  @unreadPosts={{this.topic.unread_posts}}
  @unseen={{this.topic.unseen}}
  @url={{this.topic.lastUnreadUrl}}
/>

<a href={{this.topic.lastPostUrl}} class="last-posted-at">{{format-age
    this.topic.last_posted_at
  }}</a>