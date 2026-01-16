import { concat, fn } from "@ember/helper";
import DBreadcrumbsItem from "discourse/components/d-breadcrumbs-item";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ChannelDetails from "../../../../components/channel-details";

<template>
  <DBreadcrumbsItem
    @path="/admin/plugins/discourse-chat-integration/providers/{{@controller.model.provider.name}}"
    @label={{i18n
      (concat
        "chat_integration.provider." @controller.model.provider.name ".title"
      )
    }}
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
    <div class="admin-config-area__header">
      <DButton
        @label="chat_integration.create_channel"
        @title="chat_integration.create_channel"
        @action={{fn @controller.createChannel @controller.model.provider}}
        @icon="plus"
        id="create-channel"
        class="btn-primary"
      />
    </div>
    {{#if @controller.model.channels.content.length}}
      <div class="admin-config-area__primary-content">
        {{#each @controller.model.channels.content as |channel|}}
          <ChannelDetails
            @channel={{channel}}
            @provider={{@controller.model.provider}}
            @refresh={{@controller.refresh}}
            @editChannel={{@controller.editChannel}}
            @test={{@controller.testChannel}}
            @createRule={{@controller.createRule}}
            @editRuleWithChannel={{@controller.editRuleWithChannel}}
            @showError={{@controller.showError}}
          />
        {{/each}}
      </div>
    {{else}}
      <div class="admin-config-area__empty-list">
        <p>{{i18n "chat_integration.no_channels"}}</p>
      </div>
    {{/if}}
  </div>
</template>
