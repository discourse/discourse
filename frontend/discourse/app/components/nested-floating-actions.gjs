import Component from "@glimmer/component";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import PluginOutlet from "discourse/components/plugin-outlet";
import TopicAdminMenu from "discourse/components/topic-admin-menu";
import concatClass from "discourse/helpers/concat-class";
import lazyHash from "discourse/helpers/lazy-hash";
import TopicNotificationsButton from "discourse/select-kit/components/topic-notifications-button";
import { i18n } from "discourse-i18n";

export default class NestedFloatingActions extends Component {
  @service composer;
  @service currentUser;

  get topicController() {
    return getOwner(this).lookup("controller:topic");
  }

  get topicRoute() {
    return getOwner(this).lookup("route:topic");
  }

  get canCreatePost() {
    return this.currentUser && this.args.topic?.details?.can_create_post;
  }

  <template>
    <div
      class={{concatClass
        "nested-view__floating-actions"
        (if this.composer.visible "--hidden")
      }}
    >
      <PluginOutlet
        @name="nested-view-floating-actions"
        @outletArgs={{lazyHash topic=@topic}}
      />

      {{#if this.currentUser}}
        <TopicNotificationsButton @topic={{@topic}} @expanded={{false}} />
      {{/if}}

      <TopicAdminMenu
        @topic={{@topic}}
        @toggleMultiSelect={{this.topicController.toggleMultiSelect}}
        @deleteTopic={{this.topicController.deleteTopic}}
        @recoverTopic={{this.topicController.recoverTopic}}
        @toggleClosed={{this.topicController.toggleClosed}}
        @toggleArchived={{this.topicController.toggleArchived}}
        @toggleVisibility={{this.topicController.toggleVisibility}}
        @resetBumpDate={{this.topicController.resetBumpDate}}
        @convertToPublicTopic={{this.topicController.convertToPublicTopic}}
        @convertToPrivateMessage={{this.topicController.convertToPrivateMessage}}
        @showTopicSlowModeUpdate={{this.topicRoute.showTopicSlowModeUpdate}}
        @showTopicTimerModal={{this.topicRoute.showTopicTimerModal}}
        @showFeatureTopic={{this.topicRoute.showFeatureTopic}}
        @showChangeTimestamp={{this.topicRoute.showChangeTimestamp}}
      />

      {{#if this.canCreatePost}}
        <DButton
          class="btn-primary nested-view__floating-reply"
          @action={{@replyAction}}
          @icon="reply"
          @label="topic.reply.title"
          title={{i18n "topic.reply.help"}}
        />
      {{/if}}
    </div>
  </template>
}
