import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { showEntrance } from "discourse/components/topic-list-item";

@tagName("tr")
@classNameBindings(":category-topic-link", "topic.archived", "topic.visited")
export default class MobileCategoryTopic extends Component {
  click = showEntrance;
}
<td class="main-link">
  <div class="topic-inset">
    {{raw "topic-status" topic=this.topic}}
    {{topic-link this.topic}}
    {{#if this.topic.unseen}}
      <span class="badge-notification new-topic"></span>
    {{/if}}
    <span
      class={{cold-age-class this.topic.last_posted_at}}
      title={{raw-date this.topic.last_posted_at}}
    >{{format-age this.topic.last_posted_at}}</span>
  </div>
</td>
<td class="num posts">{{raw
    "list/post-count-or-badges"
    topic=this.topic
    postBadgesEnabled="true"
  }}</td>