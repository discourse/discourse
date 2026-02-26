import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
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

  <div class="admin-config-area">
    {{#if @controller.model.channels.content.length}}
      <div class="admin-config-area__header">
        {{#if @controller.showNewChannelForm}}
          <InlineChannelForm
            @channel={{@controller.newChannel}}
            @provider={{@controller.model.provider}}
            @onSave={{@controller.onChannelSaved}}
            @onCancel={{@controller.cancelNewChannel}}
          />
        {{else}}
          <DButton
            @label="chat_integration.add_channel"
            @title="chat_integration.add_channel"
            @action={{@controller.createChannel}}
            @icon="plus"
            id="create-channel"
            class="btn-primary"
          />
        {{/if}}
      </div>
      <div class="admin-config-area__primary-content">
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
      <InlineChannelForm
        @channel={{@controller.newChannel}}
        @provider={{@controller.model.provider}}
        @onSave={{@controller.onChannelSaved}}
        @isFirstChannel={{true}}
      />
    {{/if}}
  </div>
</template>
