import Component from "@glimmer/component";
import { action, get, set } from "@ember/object";
import { durationTextFromSeconds } from "discourse/helpers/slow-mode";
import { popupAjaxError } from "discourse/lib/ajax-error";
import Topic from "discourse/models/topic";
import DButton from "discourse/ui-kit/d-button";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

export default class SlowModeInfo extends Component {
  // `slow_mode_seconds` and `closed` are plain fields on the topic model, so they are
  // only tracked when read through `get`.
  get durationText() {
    return durationTextFromSeconds(
      this.args.topic && get(this.args.topic, "slow_mode_seconds")
    );
  }

  get showSlowModeNotice() {
    if (!this.args.topic) {
      return false;
    }

    return (
      get(this.args.topic, "slow_mode_seconds") > 0 &&
      !get(this.args.topic, "closed")
    );
  }

  @action
  disableSlowMode() {
    Topic.setSlowMode(this.args.topic.id, 0)
      .catch(popupAjaxError)
      .then(() => set(this.args.topic, "slow_mode_seconds", 0));
  }

  <template>
    {{#if this.showSlowModeNotice}}
      <div class="topic-status-info">
        <h3 class="slow-mode-heading">
          <span>
            {{dIcon "hourglass-start"}}
            {{i18n
              "topic.slow_mode_notice.duration"
              duration=this.durationText
            }}
          </span>

          {{#if @user.canManageTopic}}
            <DButton
              class="slow-mode-remove"
              @action={{this.disableSlowMode}}
              @icon="trash-can"
            />
          {{/if}}
        </h3>
      </div>
    {{/if}}
  </template>
}
