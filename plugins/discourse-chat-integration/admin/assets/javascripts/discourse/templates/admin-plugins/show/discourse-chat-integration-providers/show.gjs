import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelDetails from "../../../../components/channel-details";
import InlineChannelForm from "../../../../components/inline-channel-form";

export default class extends Component {
  @service router;

  get providerTitle() {
    return i18n(
      `chat_integration.provider.${this.args.controller.model.provider.name}.title`
    );
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
      @path="/admin/plugins/discourse-chat-integration/providers/{{@controller.model.provider.name}}"
      @label={{this.providerTitle @controller.model.provider}}
    />

    {{#if @controller.anyErrors}}
      <div class="alert alert-error chat-integration-error-banner">
        {{icon "triangle-exclamation"}}
        <span class="error-message">
          {{i18n "chat_integration.channels_with_errors"}}
        </span>
      </div>
    {{/if}}

    <div class="admin-detail">
      <DPageSubheader @titleLabel={{i18n "chat_integration.channels_title"}}>
        <:actions as |actions|>
          <actions.Default
            @label="chat_integration.view_provider_settings"
            @title="chat_integration.view_provider_settings"
            @action={{fn this.configureProvider @controller.model.provider}}
            @icon="gear"
            id="view-provider-settings"
          />
          {{#unless @controller.showNewChannelForm}}
            <actions.Primary
              @label="chat_integration.add_channel"
              @title="chat_integration.add_channel"
              @action={{@controller.createChannel}}
              @icon="plus"
              id="create-channel"
            />
          {{/unless}}
        </:actions>
      </DPageSubheader>

      {{#if @controller.showNewChannelForm}}
        <InlineChannelForm
          @channel={{@controller.newChannel}}
          @provider={{@controller.model.provider}}
          @onSave={{@controller.onChannelSaved}}
          @onCancel={{@controller.cancelNewChannel}}
        />
      {{/if}}

      {{#if @controller.model.channels.content.length}}
        <div class="chat-integration-channel-list">
          {{#each @controller.model.channels.content as |channel|}}
            <ChannelDetails
              @channel={{channel}}
              @provider={{@controller.model.provider}}
              @refresh={{@controller.refresh}}
              @test={{@controller.testChannel}}
              @createRule={{@controller.createRule}}
              @editRuleWithChannel={{@controller.editRuleWithChannel}}
              @showError={{@controller.showError}}
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
