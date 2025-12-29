import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { service } from "@ember/service";
import DButton from "discourse/components/d-button";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";
import concatClass from "discourse/helpers/concat-class";
import { applyValueTransformer } from "discourse/lib/transformer";

export default class CreateTopicButton extends Component {
  @service router;
  @service siteSettings;
  @service currentUser;

  @tracked btnTypeClass = this.args.btnTypeClass || "btn-default";
  @tracked label = this.args.label ?? "topic.create";

  btnId = this.args.btnId ?? "create-topic";

  get permissionClass() {
    return applyValueTransformer("create-topic-button-class", "", {
      disabled: this.args.disabled,
      canCreateTopic: this.args.canCreateTopic,
      category: this.router.currentRoute?.attributes?.category,
      tag: this.router.currentRoute?.attributes?.tag,
      currentUser: this.currentUser,
      siteSettings: this.siteSettings,
    });
  }

  <template>
    {{#if @canCreateTopic}}
      <DButton
        @action={{@action}}
        @icon="far-pen-to-square"
        @label={{this.label}}
        id={{this.btnId}}
        class={{concatClass @btnClass this.btnTypeClass this.permissionClass}}
      />

      {{#if @showDrafts}}
        <TopicDraftsDropdown
          @disabled={{false}}
          @btnTypeClass={{this.btnTypeClass}}
        />
      {{/if}}
    {{/if}}
  </template>
}
