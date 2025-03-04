import Component from "@ember/component";
import { action } from "@ember/object";
import { durationTextFromSeconds } from "discourse/helpers/slow-mode";
import { popupAjaxError } from "discourse/lib/ajax-error";
import discourseComputed from "discourse/lib/decorators";
import Topic from "discourse/models/topic";
import dIcon from "discourse/helpers/d-icon";
import iN from "discourse/helpers/i18n";
import DButton from "discourse/components/d-button";

export default class SlowModeInfo extends Component {<template>{{#if this.showSlowModeNotice}}
  <div class="topic-status-info">
    <h3 class="slow-mode-heading">
      <span>
        {{dIcon "hourglass-start"}}
        {{iN "topic.slow_mode_notice.duration" duration=this.durationText}}
      </span>

      {{#if this.user.canManageTopic}}
        <DButton @action={{this.disableSlowMode}} @icon="trash-can" class="slow-mode-remove" />
      {{/if}}
    </h3>
  </div>
{{/if}}</template>
  @discourseComputed("topic.slow_mode_seconds")
  durationText(seconds) {
    return durationTextFromSeconds(seconds);
  }

  @discourseComputed("topic.slow_mode_seconds", "topic.closed")
  showSlowModeNotice(seconds, closed) {
    return seconds > 0 && !closed;
  }

  @action
  disableSlowMode() {
    Topic.setSlowMode(this.topic.id, 0)
      .catch(popupAjaxError)
      .then(() => this.set("topic.slow_mode_seconds", 0));
  }
}
