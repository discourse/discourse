import Component from "@ember/component";
import { tagName } from "@ember-decorators/component";
import DButtonTooltip from "float-kit/components/d-button-tooltip";
import DButton from "discourse/components/d-button";
import DTooltip from "float-kit/components/d-tooltip";
import iN from "discourse/helpers/i18n";
import TopicDraftsDropdown from "discourse/components/topic-drafts-dropdown";

@tagName("")
export default class CreateTopicButton extends Component {<template>{{#if this.canCreateTopic}}
  <DButtonTooltip>
    <:button>
      <DButton @action={{this.action}} @icon="far-pen-to-square" @disabled={{this.disabled}} @label={{this.label}} id="create-topic" class={{this.btnClass}} />
    </:button>
    <:tooltip>
      {{#if @disabled}}
        <DTooltip @icon="circle-info" @content={{iN this.disallowedReason}} />
      {{/if}}
    </:tooltip>
  </DButtonTooltip>

  {{#if @showDrafts}}
    <TopicDraftsDropdown @disabled={{this.disabled}} />
  {{/if}}
{{/if}}</template>
  label = "topic.create";
  btnClass = "btn-default";

  get disallowedReason() {
    if (this.canCreateTopicOnTag === false) {
      return "topic.create_disabled_tag";
    } else if (this.disabled) {
      return "topic.create_disabled_category";
    }
  }
}
