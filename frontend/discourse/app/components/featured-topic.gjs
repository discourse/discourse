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
    <TopicStatus @disableActions={{true}} @topic={{this.topic}} />
    <a class="title" href={{this.topic.lastUnreadUrl}}>{{trustHTML
        this.topic.fancyTitle
      }}</a>
    <TopicPostBadges
      @unreadPosts={{this.topic.unread_posts}}
      @unseen={{this.topic.unseen}}
      @url={{this.topic.lastUnreadUrl}}
    />

    <a class="last-posted-at" href={{this.topic.lastPostUrl}}>{{dAgeWithTooltip
        this.topic.last_posted_at
      }}</a>
  </template>
}
