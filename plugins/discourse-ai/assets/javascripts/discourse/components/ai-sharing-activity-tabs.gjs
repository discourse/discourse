import Component from "@glimmer/component";
import { service } from "@ember/service";
import DNavigationItem from "discourse/ui-kit/d-navigation-item";
import { i18n } from "discourse-i18n";

export default class AiSharingActivityTabs extends Component {
  @service currentUser;
  @service siteSettings;

  get showConversations() {
    return (
      this.siteSettings.discourse_ai_enabled &&
      this.currentUser &&
      this.currentUser.id === this.args.outletArgs?.model?.id
    );
  }

  get showArtifacts() {
    return this.showConversations;
  }

  <template>
    {{#if this.showArtifacts}}
      <DNavigationItem
        class="user-nav__activity-shared-artifacts"
        @ariaCurrentContext="subNav"
        @route="userActivity.sharedAiArtifacts"
      >
        {{i18n "discourse_ai.ai_artifact.shared_artifacts"}}
      </DNavigationItem>
    {{/if}}
    {{#if this.showConversations}}
      <DNavigationItem
        class="user-nav__activity-shared-conversations"
        @ariaCurrentContext="subNav"
        @route="userActivity.sharedAiConversations"
      >
        {{i18n "discourse_ai.shared_ai_conversations.title"}}
      </DNavigationItem>
    {{/if}}
  </template>
}
