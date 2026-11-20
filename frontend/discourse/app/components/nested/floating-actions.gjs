import Component from "@glimmer/component";
import { action } from "@ember/object";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import lazyHash from "discourse/helpers/lazy-hash";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class NestedFloatingActions extends Component {
  @service composer;
  @service currentUser;

  topicController = getOwner(this).lookup("controller:topic");
  topicRoute = getOwner(this).lookup("route:topic");

  get canCreatePost() {
    return this.args.topic?.details?.can_create_post;
  }

  get showReplyButton() {
    return !this.currentUser || this.canCreatePost;
  }

  @action
  reply() {
    if (!this.currentUser) {
      return getOwner(this).lookup("route:application").send("showLogin");
    }

    return this.args.replyAction?.();
  }

  <template>
    <div
      class={{dConcatClass
        "nested-view__floating-actions"
        (if this.composer.visible "--hidden")
      }}
    >
      <PluginOutlet
        @name="nested-view-floating-actions"
        @outletArgs={{lazyHash topic=@topic}}
      />

      {{#if this.currentUser}}
        <TopicNotificationsButton @expanded={{false}} @topic={{@topic}} />
      {{/if}}

      <TopicAdminMenu
        @convertToPrivateMessage={{this.topicController.convertToPrivateMessage}}
        @convertToPublicTopic={{this.topicController.convertToPublicTopic}}
        @deleteTopic={{this.topicController.deleteTopic}}
        @recoverTopic={{this.topicController.recoverTopic}}
        @resetBumpDate={{this.topicController.resetBumpDate}}
        @showChangeTimestamp={{this.topicRoute.showChangeTimestamp}}
        @showFeatureTopic={{this.topicRoute.showFeatureTopic}}
        @showTopicSlowModeUpdate={{this.topicRoute.showTopicSlowModeUpdate}}
        @showTopicTimerModal={{this.topicRoute.showTopicTimerModal}}
        @toggleArchived={{this.topicController.toggleArchived}}
        @toggleClosed={{this.topicController.toggleClosed}}
        @toggleMultiSelect={{this.topicController.toggleMultiSelect}}
        @toggleVisibility={{this.topicController.toggleVisibility}}
        @topic={{@topic}}
      />

      {{#if this.showReplyButton}}
        <DButton
          class="btn-primary nested-view__floating-reply"
          title={{i18n "topic.reply.help"}}
          @action={{this.reply}}
          @icon="reply"
          @label="topic.reply.title"
        />
      {{/if}}
    </div>
  </template>
}
