import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/ui-kit/d-breadcrumbs-item";
import DPageSubheader from "discourse/ui-kit/d-page-subheader";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelDetails from "../../../../components/channel-details";
import InlineChannelForm from "../../../../components/inline-channel-form";
import { PROVIDER_LEARN_MORE_URLS } from "../../../../lib/utilities";

export default class extends Component {
  @service router;

  get providerTitle() {
    return i18n(
      `chat_integration.provider.${this.args.controller.model.provider.name}.title`
    );
  }

  get providerLearnMoreUrl() {
    return PROVIDER_LEARN_MORE_URLS[this.args.controller.model.provider.name];
  }

  @action
  configureProvider() {
    this.router.transitionTo("adminPlugins.show.settings", {
      queryParams: {
        filter: `chat_integration_${this.args.controller.model.provider.name}`,
      },
    });
  }

  <template>
    <DBreadcrumbsItem
      @label={{this.providerTitle @controller.model.provider}}
      @path="/admin/plugins/discourse-chat-integration/providers/{{@controller.model.provider.name}}"
    />

    {{#if @controller.anyErrors}}
      <div class="alert alert-error chat-integration-error-banner">
        {{dIcon "triangle-exclamation"}}
        <span class="error-message">
          {{i18n "chat_integration.channels_with_errors"}}
        </span>
      </div>
    {{/if}}

    <div class="admin-detail">
      <DPageSubheader
        @descriptionLabel={{i18n
          "chat_integration.channels_description"
          provider=this.providerTitle
        }}
        @learnMoreUrl={{this.providerLearnMoreUrl}}
        @titleLabel={{i18n "chat_integration.channels_title"}}
      >
        <:actions as |actions|>
          <actions.Default
            id="view-provider-settings"
            @action={{fn this.configureProvider @controller.model.provider}}
            @icon="gear"
            @label="chat_integration.view_provider_settings"
            @title="chat_integration.view_provider_settings"
          />
          {{#unless @controller.showNewChannelForm}}
            <actions.Primary
              id="create-channel"
              @action={{@controller.createChannel}}
              @icon="plus"
              @label="chat_integration.add_channel"
              @title="chat_integration.add_channel"
            />
          {{/unless}}
        </:actions>
      </DPageSubheader>

      {{#if @controller.showNewChannelForm}}
        <InlineChannelForm
          @channel={{@controller.newChannel}}
          @onCancel={{@controller.cancelNewChannel}}
          @onSave={{@controller.onChannelSaved}}
          @provider={{@controller.model.provider}}
        />
      {{/if}}

      {{#if @controller.model.channels.content.length}}
        <div class="chat-integration-channel-list">
          {{#each @controller.model.channels.content as |channel|}}
            <ChannelDetails
              @channel={{channel}}
              @createRule={{@controller.createRule}}
              @editRuleWithChannel={{@controller.editRuleWithChannel}}
              @provider={{@controller.model.provider}}
              @refresh={{@controller.refresh}}
              @showError={{@controller.showError}}
              @test={{@controller.testChannel}}
            />
          {{/each}}
        </div>
      {{else}}
        {{#unless @controller.showNewChannelForm}}
          <AdminConfigAreaEmptyList
            @emptyLabel="chat_integration.no_channels"
          />
        {{/unless}}
      {{/if}}
    </div>
  </template>
}
