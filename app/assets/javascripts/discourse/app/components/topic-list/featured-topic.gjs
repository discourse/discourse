import { on } from "@ember/modifier";
import { htmlSafe } from "@ember/template";
import TopicEntrance from "discourse/components/topic-list/topic-entrance";
import TopicPostBadges from "discourse/components/topic-post-badges";
import TopicStatus from "discourse/components/topic-status";
import formatAge from "discourse/helpers/format-age";
import { wantsNewWindow } from "discourse/lib/intercept-click";

const onTimestampClick = function (event) {
  if (wantsNewWindow(event)) {
    // Allow opening the link in a new tab/window
    event.stopPropagation();
  } else {
    // Otherwise only display the TopicEntrance component
    event.preventDefault();
  }
};

const FeaturedTopic = <template>
  <div data-topic-id={{@topic.id}} class="featured-topic --glimmer">
    <TopicStatus @topic={{@topic}} />

    <a href={{@topic.lastUnreadUrl}} class="title">{{htmlSafe
        @topic.fancyTitle
      }}</a>

    <TopicPostBadges
      @unreadPosts={{@topic.unread_posts}}
      @unseen={{@topic.unseen}}
      @url={{@topic.lastUnreadUrl}}
    />

    <TopicEntrance @topic={{@topic}}>
      <a
        {{on "click" onTimestampClick}}
        href={{@topic.lastPostUrl}}
        class="last-posted-at"
      >{{formatAge @topic.last_posted_at}}</a>
    </TopicEntrance>
  </div>
</template>;

export default FeaturedTopic;
