import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";

export default class NestedTopicActions extends Component {
  topicController = getOwner(this).lookup("controller:topic");
  topicRoute = getOwner(this).lookup("route:topic");

  <template>
    <TopicFooterButtons
      class="nested-view__topic-actions"
      @convertToPrivateMessage={{this.topicController.convertToPrivateMessage}}
      @convertToPublicTopic={{this.topicController.convertToPublicTopic}}
      @deferTopic={{this.topicController.deferTopic}}
      @deleteTopic={{this.topicController.deleteTopic}}
      @editFirstPost={{this.topicController.editFirstPost}}
      @recoverTopic={{this.topicController.recoverTopic}}
      @replyToPost={{this.topicController.replyToPost}}
      @resetBumpDate={{this.topicController.resetBumpDate}}
      @showChangeTimestamp={{this.topicRoute.showChangeTimestamp}}
      @showCreate={{false}}
      @showFeatureTopic={{this.topicRoute.showFeatureTopic}}
      @showFlagTopic={{this.topicRoute.showFlagTopic}}
      @showTopicSlowModeUpdate={{this.topicRoute.showTopicSlowModeUpdate}}
      @showTopicTimerModal={{this.topicRoute.showTopicTimerModal}}
      @toggleArchived={{this.topicController.toggleArchived}}
      @toggleArchiveMessage={{this.topicController.toggleArchiveMessage}}
      @toggleBookmark={{this.topicController.toggleBookmark}}
      @toggleClosed={{this.topicController.toggleClosed}}
      @toggleMultiSelect={{this.topicController.toggleMultiSelect}}
      @toggleVisibility={{this.topicController.toggleVisibility}}
      @topic={{@topic}}
    />
  </template>
}
