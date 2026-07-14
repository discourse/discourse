import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import TopicFooterButtons from "discourse/components/topic-footer-buttons";

export default class NestedTopicActions extends Component {
  topicController = getOwner(this).lookup("controller:topic");
  topicRoute = getOwner(this).lookup("route:topic");

  <template>
    <TopicFooterButtons
      @topic={{@topic}}
      @toggleMultiSelect={{this.topicController.toggleMultiSelect}}
      @showTopicSlowModeUpdate={{this.topicRoute.showTopicSlowModeUpdate}}
      @deleteTopic={{this.topicController.deleteTopic}}
      @recoverTopic={{this.topicController.recoverTopic}}
      @toggleClosed={{this.topicController.toggleClosed}}
      @toggleArchived={{this.topicController.toggleArchived}}
      @toggleVisibility={{this.topicController.toggleVisibility}}
      @showTopicTimerModal={{this.topicRoute.showTopicTimerModal}}
      @showFeatureTopic={{this.topicRoute.showFeatureTopic}}
      @showChangeTimestamp={{this.topicRoute.showChangeTimestamp}}
      @resetBumpDate={{this.topicController.resetBumpDate}}
      @convertToPublicTopic={{this.topicController.convertToPublicTopic}}
      @convertToPrivateMessage={{this.topicController.convertToPrivateMessage}}
      @toggleBookmark={{this.topicController.toggleBookmark}}
      @showFlagTopic={{this.topicRoute.showFlagTopic}}
      @toggleArchiveMessage={{this.topicController.toggleArchiveMessage}}
      @editFirstPost={{this.topicController.editFirstPost}}
      @deferTopic={{this.topicController.deferTopic}}
      @replyToPost={{this.topicController.replyToPost}}
      @showCreate={{false}}
      class="nested-view__topic-actions"
    />
  </template>
}
