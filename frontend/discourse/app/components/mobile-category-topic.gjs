/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { classNameBindings, tagName } from "@ember-decorators/component";
import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicStatus from "discourse/components/topic-status";
import coldAgeClass from "discourse/helpers/cold-age-class";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";

@tagName("tr")
@classNameBindings(":category-topic-link", "topic.archived", "topic.visited")
export default class MobileCategoryTopic extends Component {
  <template>
    <td class="main-link">
      <div class="topic-inset">
        <TopicStatus @topic={{this.topic}} @disableActions={{true}} />
        {{dTopicLink this.topic}}
        {{#if this.topic.unseen}}
          <span class="badge-notification new-topic"></span>
        {{/if}}
        <span class={{coldAgeClass this.topic.last_posted_at}}>{{dAgeWithTooltip
            this.topic.last_posted_at
          }}</span>
      </div>
    </td>
    <td class="num posts">
      <PostCountOrBadges @topic={{this.topic}} @postBadgesEnabled={{true}} />
    </td>
  </template>
}
