import Component from "@glimmer/component";
import { service } from "@ember/service";
import DTooltip from "discourse/float-kit/components/d-tooltip";
import { until } from "discourse/lib/formatter";
import type User from "discourse/models/user";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";

/** Legacy global supplied by the application, without introducing a module import. */
declare const moment: typeof import("moment");

/** A user status. */
export interface DUserStatus {
  /** The emoji of the status. */
  emoji: string;

  /** The text of the status. */
  description: string;

  /** When the status ends, if it expires. */
  ends_at?: string | null;
}

interface DUserStatusMessageSignature {
  Args: {
    /** The status to show. Without it, nothing is rendered. */
    status?: DUserStatus | null;

    /** Whether to show the description next to the emoji. */
    showDescription?: boolean;
  };

  Element: HTMLSpanElement;
}

export default class DUserStatusMessage extends Component<DUserStatusMessageSignature> {
  @service declare currentUser: User | null;

  get until() {
    const endsAt = this.args.status?.ends_at;
    if (!endsAt) {
      return;
    }

    const timezone = this.currentUser
      ? this.currentUser.user_option?.timezone
      : moment.tz.guess();

    return until(endsAt, timezone, this.currentUser?.locale);
  }

  <template>
    {{#if @status}}
      <DTooltip
        class="user-status-message"
        ...attributes
        @identifier="user-status-message-tooltip"
      >
        <:trigger>
          {{dEmoji @status.emoji skipTitle=true}}
          {{#if @showDescription}}
            <span class="user-status-message-description">
              {{@status.description}}
            </span>
          {{/if}}
        </:trigger>
        <:content>
          {{dEmoji @status.emoji skipTitle=true}}
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
