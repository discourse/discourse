/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import DButton from "discourse/components/d-button";
import icon from "discourse/helpers/d-icon";
import { durationTextFromSeconds } from "discourse/helpers/slow-mode";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Topic from "discourse/models/topic";
import { i18n } from "discourse-i18n";

export default class SlowModeInfo extends Component {
  @computed("topic.slow_mode_seconds")
  get durationText() {
    return durationTextFromSeconds(this.topic?.slow_mode_seconds);
  }

  @computed("topic.slow_mode_seconds", "topic.closed")
  get showSlowModeNotice() {
    return this.topic?.slow_mode_seconds > 0 && !this.topic?.closed;
  }

  @action
  disableSlowMode() {
    Topic.setSlowMode(this.topic.id, 0)
      .catch(popupAjaxError)
      .then(() => this.set("topic.slow_mode_seconds", 0));
  }

  <template>
    {{#if this.showSlowModeNotice}}
      <div class="topic-status-info">
        <h3 class="slow-mode-heading">
          <span>
            {{icon "hourglass-start"}}
            {{i18n
              "topic.slow_mode_notice.duration"
              duration=this.durationText
            }}
          </span>

          {{#if this.user.canManageTopic}}
            <DButton
              @action={{this.disableSlowMode}}
              @icon="trash-can"
              class="slow-mode-remove"
            />
          {{/if}}
        </h3>
      </div>
    {{/if}}
  </template>
}
