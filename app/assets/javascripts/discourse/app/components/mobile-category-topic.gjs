import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import { showEntrance } from "discourse/components/topic-list-item";
import coldAgeClass from "discourse/helpers/cold-age-class";
import formatAge from "discourse/helpers/format-age";
import raw from "discourse/helpers/raw";
import rawDate from "discourse/helpers/raw-date";
import topicLink from "discourse/helpers/topic-link";

@tagName("tr")
@classNameBindings(":category-topic-link", "topic.archived", "topic.visited")
export default class MobileCategoryTopic extends Component {
  click = showEntrance;

  <template>
    <td class="main-link">
      <div class="topic-inset">
        {{raw "topic-status" topic=this.topic}}
        {{topicLink this.topic}}
        {{#if this.topic.unseen}}
          <span class="badge-notification new-topic"></span>
        {{/if}}
        <span
          class={{coldAgeClass this.topic.last_posted_at}}
          title={{rawDate this.topic.last_posted_at}}
        >{{formatAge this.topic.last_posted_at}}</span>
      </div>
    </td>
    <td class="num posts">{{raw
        "list/post-count-or-badges"
        topic=this.topic
        postBadgesEnabled="true"
      }}</td>
  </template>
}
