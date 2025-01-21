import Component from "@glimmer/component";
import { service } from "@ember/service";
import emoji from "discourse/helpers/emoji";
import { until } from "discourse/lib/formatter";
import DTooltip from "float-kit/components/d-tooltip";

export default class UserStatusMessage extends Component {
  @service currentUser;

  get until() {
    if (!this.args.status.ends_at) {
      return;
    }

    const timezone = this.currentUser
      ? this.currentUser.user_option?.timezone
      : moment.tz.guess();

    return until(this.args.status.ends_at, timezone, this.currentUser?.locale);
  }

  <template>
    {{#if @status}}
      <DTooltip
        @identifier="user-status-message-tooltip"
        class="user-status-message"
        ...attributes
      >
        <:trigger>
          {{emoji @status.emoji skipTitle=true}}
          {{#if @showDescription}}
            <span class="user-status-message-description">
              {{@status.description}}
            </span>
          {{/if}}
        </:trigger>
        <:content>
          {{emoji @status.emoji skipTitle=true}}
          <div class="user-status-tooltip-wrapper">
            <span class="user-status-tooltip-description">
              {{@status.description}}
            </span>
            {{#if this.until}}
              <span class="user-status-tooltip-until">
                {{this.until}}
              </span>
            {{/if}}
          </div>
        </:content>
      </DTooltip>
    {{/if}}
  </template>
}
