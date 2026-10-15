import PostCountOrBadges from "discourse/components/topic-list/post-count-or-badges";
import TopicStatus from "discourse/components/topic-status";
import coldAgeClass from "discourse/helpers/cold-age-class";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dTopicLink from "discourse/ui-kit/helpers/d-topic-link";

const MobileCategoryTopic = <template>
  <tr
    class={{dConcatClass
      "category-topic-link"
      (if @topic.archived "archived")
      (if @topic.visited "visited")
    }}
    ...attributes
  >
    <td class="main-link">
      <div class="topic-inset">
        <TopicStatus @disableActions={{true}} @topic={{@topic}} />
        {{dTopicLink @topic}}
        {{#if @topic.unseen}}
          <span class="badge-notification new-topic"></span>
        {{/if}}
        <span class={{coldAgeClass @topic.last_posted_at}}>{{dAgeWithTooltip
            @topic.last_posted_at
          }}</span>
      </div>
    </td>
    <td class="num posts">
      <PostCountOrBadges @postBadgesEnabled={{true}} @topic={{@topic}} />
    </td>
  </tr>
</template>;

export default MobileCategoryTopic;
