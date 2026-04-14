import AdminConfigAreaEmptyList from "discourse/admin/components/admin-config-area-empty-list";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DPageSubheader from "discourse/components/d-page-subheader";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelDetails from "../../../../components/channel-details";
import InlineChannelForm from "../../../../components/inline-channel-form";

const providerTitle = (provider) =>
  i18n(`chat_integration.provider.${provider.name}.title`);

<template>
  <DBreadcrumbsItem
    @path="/admin/plugins/discourse-chat-integration/providers/{{@controller.model.provider.name}}"
    @label={{providerTitle @controller.model.provider}}
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
        <AdminConfigAreaEmptyList @emptyLabel="chat_integration.no_channels" />
      {{/unless}}
    {{/if}}
  </div>
</template>
