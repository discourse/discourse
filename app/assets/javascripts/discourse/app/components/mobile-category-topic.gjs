import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import $ from "jquery";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicStatus from "discourse/components/topic-status";
import ageWithTooltip from "discourse/helpers/age-with-tooltip";
import coldAgeClass from "discourse/helpers/cold-age-class";
import topicLink from "discourse/helpers/topic-link";

export function showEntrance(e) {
  let target = $(e.target);

  if (target.hasClass("posts-map") || target.parents(".posts-map").length > 0) {
    if (target.prop("tagName") !== "A") {
      target = target.find("a");
      if (target.length === 0) {
        target = target.end();
      }
    }

    this.appEvents.trigger("topic-entrance:show", {
      topic: this.topic,
      position: target.offset(),
    });
    return false;
  }
}

@tagName("tr")
@classNameBindings(":category-topic-link", "topic.archived", "topic.visited")
export default class MobileCategoryTopic extends Component {
  click = showEntrance;

  <template>
    <td class="main-link">
      <div class="topic-inset">
        <TopicStatus @topic={{this.topic}} @disableActions={{true}} />
        {{topicLink this.topic}}
        {{#if this.topic.unseen}}
          <span class="badge-notification new-topic"></span>
        {{/if}}
        <span class={{coldAgeClass this.topic.last_posted_at}}>{{ageWithTooltip
            this.topic.last_posted_at
          }}</span>
      </div>
    </td>
    <td class="num posts">
      <PostCountOrBadges @topic={{this.topic}} @postBadgesEnabled={{true}} />
    </td>
  </template>
}
