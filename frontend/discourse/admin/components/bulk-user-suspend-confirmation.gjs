import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { trackedArray } from "@ember/reactive/collections";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { modifier as modifierFn } from "ember-modifier";
import AdminPenaltyReason from "discourse/admin/components/admin-penalty-reason";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { bind } from "discourse/lib/decorators";
import DButton from "discourse/ui-kit/d-button";
import DFutureDateInput from "discourse/ui-kit/d-future-date-input";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

const BULK_SUSPEND_CHANNEL = "/bulk-user-suspend";

export default class BulkUserSuspendConfirmation extends Component {
  @service messageBus;

  @tracked suspendUntil;
  @tracked reason;
  @tracked suspendStarted = false;
  @tracked submitting = false;
  message;

  logs = trackedArray();
  failedUsernames = [];

  callAfterBulkSuspend = false;

  logsListener = modifierFn(() => {
    this.messageBus.subscribe(BULK_SUSPEND_CHANNEL, this.onSuspendProgress);

    return () => {
      this.messageBus.unsubscribe(BULK_SUSPEND_CHANNEL, this.onSuspendProgress);
    };
  });

  get submitDisabled() {
    return (
      this.submitting ||
      isEmpty(this.suspendUntil) ||
      isEmpty(this.reason?.trim())
    );
  }

  #logError(line) {
    this.#log(line, "error");
  }

  #logSuccess(line) {
    this.#log(line, "success");
  }

  #logNeutral(line) {
    this.#log(line, "neutral");
  }

  #log(line, type) {
    this.logs.push({
      line,
      type,
    });
  }

  @bind
  onSuspendProgress(data) {
    if (data.success) {
      this.#logSuccess(
        i18n(
          "admin.users.bulk_actions.suspend.confirmation_modal.user_suspend_succeeded",
          data
        )
      );
    } else if (data.failed) {
      this.failedUsernames.push(data.username);
      this.#logError(
        i18n(
          "admin.users.bulk_actions.suspend.confirmation_modal.user_suspend_failed",
          data
        )
      );
    }

    if (data.position === data.total) {
      this.callAfterBulkSuspend = true;
      this.#logNeutral(
        i18n(
          "admin.users.bulk_actions.suspend.confirmation_modal.bulk_suspend_finished"
        )
      );
      if (this.failedUsernames.length > 0) {
        this.#logNeutral(
          i18n(
            "admin.users.bulk_actions.suspend.confirmation_modal.failed_to_suspend_users"
          )
        );
        for (const username of this.failedUsernames) {
          this.#logNeutral(`* ${username}`);
        }
      }
    }
  }

  @action
  async startSuspend() {
    this.submitting = true;
    this.suspendStarted = true;
    this.#logNeutral(
      i18n(
        "admin.users.bulk_actions.suspend.confirmation_modal.bulk_suspend_starting"
      )
    );

    try {
      await ajax("/admin/users/suspend-bulk.json", {
        type: "PUT",
        data: {
          user_ids: this.args.model.userIds,
          suspend_until: this.suspendUntil,
          reason: this.reason,
          message: this.message,
        },
      });
      this.callAfterBulkSuspend = true;
    } catch (err) {
      this.#logError(extractError(err));
      this.submitting = false;
    }
  }

  @action
  closeModal() {
    this.args.closeModal();
    if (this.callAfterBulkSuspend) {
      this.args.model?.afterBulkAction();
    }
  }

  <template>
    <DModal
      class="bulk-user-suspend-confirmation"
      @closeModal={{this.closeModal}}
      @title={{i18n
        "admin.users.bulk_actions.suspend.confirmation_modal.title"
        count=@model.userIds.length
      }}
      {{this.logsListener}}
    >
      <:body>
        {{#if this.suspendStarted}}
          <div class="bulk-user-suspend-confirmation__progress">
            {{#each this.logs as |entry|}}
              <div
                class="bulk-user-suspend-confirmation__progress-line -{{entry.type}}"
              >
                {{entry.line}}
              </div>
            {{/each}}
            <div class="bulk-user-suspend-confirmation__progress-anchor">
            </div>
          </div>
        {{else}}
          <p>{{i18n
              "admin.users.bulk_actions.suspend.confirmation_modal.prompt_text"
              count=@model.userIds.length
            }}
          </p>
          <DFutureDateInput
            @label="admin.user.suspend_duration"
            @clearable={{false}}
            @input={{this.suspendUntil}}
            @onChangeInput={{fn (mut this.suspendUntil)}}
            class="suspend-until"
          />
          <AdminPenaltyReason
            @penaltyType="suspend"
            @reason={{this.reason}}
            @message={{this.message}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="confirm-suspend btn-danger"
          @icon="ban"
          @label="admin.users.bulk_actions.suspend.confirmation_modal.confirm"
          @disabled={{this.submitDisabled}}
          @action={{this.startSuspend}}
        />
        <DButton
          class="btn-default"
          @label="admin.users.bulk_actions.suspend.confirmation_modal.close"
          @action={{this.closeModal}}
        />
      </:footer>
    </DModal>
  </template>
}
