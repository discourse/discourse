/* eslint-disable ember/no-classic-components, ember/require-tagless-components */
import Component from "@ember/component";
import { trustHTML } from "@ember/template";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import TopicPostBadges from "discourse/components/topic-post-badges";
import dAgeWithTooltip from "discourse/ui-kit/helpers/d-age-with-tooltip";
import TopicStatus from "./topic-status";

@classNameBindings(":featured-topic")
@attributeBindings("topic.id:data-topic-id")
export default class FeaturedTopic extends Component {
  <template>
    <TopicStatus @topic={{this.topic}} @disableActions={{true}} />
    <a href={{this.topic.lastUnreadUrl}} class="title">{{trustHTML
        this.topic.fancyTitle
      }}</a>
    <TopicPostBadges
      @unreadPosts={{this.topic.unread_posts}}
      @unseen={{this.topic.unseen}}
      @url={{this.topic.lastUnreadUrl}}
    />

    <a href={{this.topic.lastPostUrl}} class="last-posted-at">{{dAgeWithTooltip
        this.topic.last_posted_at
      }}</a>
  </template>
}
