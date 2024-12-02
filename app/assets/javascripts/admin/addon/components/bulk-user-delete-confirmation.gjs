import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { TrackedArray } from "tracked-built-ins";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { bind } from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const BULK_DELETE_CHANNEL = "/bulk-user-delete";

export default class BulkUserDeleteConfirmation extends Component {
  @service messageBus;

  @tracked confirmButtonDisabled = true;
  @tracked deleteStarted = false;
  @tracked logs = new TrackedArray();
  failedUsernames = [];

  callAfterBulkDelete = false;

  constructor() {
    super(...arguments);
    this.messageBus.subscribe(BULK_DELETE_CHANNEL, this.onDeleteProgress);
  }

  willDestroy() {
    super.willDestroy(...arguments);
    this.messageBus.unsubscribe(BULK_DELETE_CHANNEL, this.onDeleteProgress);
  }

  get confirmDeletePhrase() {
    return i18n(
      "admin.users.bulk_actions.delete.confirmation_modal.confirmation_phrase",
      { count: this.args.model.userIds.length }
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
  onDeleteProgress(data) {
    if (data.success) {
      this.#logSuccess(
        i18n(
          "admin.users.bulk_actions.delete.confirmation_modal.user_delete_succeeded",
          data
        )
      );
    } else if (data.failed) {
      this.failedUsernames.push(data.username);
      this.#logError(
        i18n(
          "admin.users.bulk_actions.delete.confirmation_modal.user_delete_failed",
          data
        )
      );
    }

    if (data.position === data.total) {
      this.callAfterBulkDelete = true;
      this.#logNeutral(
        i18n(
          "admin.users.bulk_actions.delete.confirmation_modal.bulk_delete_finished"
        )
      );
      if (this.failedUsernames.length > 0) {
        this.#logNeutral(
          i18n(
            "admin.users.bulk_actions.delete.confirmation_modal.failed_to_delete_users"
          )
        );
        for (const username of this.failedUsernames) {
          this.#logNeutral(`* ${username}`);
        }
      }
    }
  }

  @action
  onPromptInput(event) {
    this.confirmButtonDisabled =
      event.target.value.toLowerCase() !== this.confirmDeletePhrase;
  }

  @action
  async startDelete() {
    this.deleteStarted = true;
    this.confirmButtonDisabled = true;
    this.#logNeutral(
      i18n(
        "admin.users.bulk_actions.delete.confirmation_modal.bulk_delete_starting"
      )
    );

    try {
      await ajax("/admin/users/destroy-bulk.json", {
        type: "DELETE",
        data: { user_ids: this.args.model.userIds },
      });
      this.callAfterBulkDelete = true;
    } catch (err) {
      this.#logError(extractError(err));
      this.confirmButtonDisabled = false;
    }
  }

  @action
  closeModal() {
    this.args.closeModal();
    if (this.callAfterBulkDelete) {
      this.args.model?.afterBulkDelete();
    }
  }

  <template>
    <DModal
      class="bulk-user-delete-confirmation"
      @closeModal={{this.closeModal}}
      @title={{i18n
        "admin.users.bulk_actions.delete.confirmation_modal.title"
        count=@model.userIds.length
      }}
    >
      <:body>
        {{#if this.deleteStarted}}
          <div class="bulk-user-delete-confirmation__progress">
            {{#each this.logs as |entry|}}
              <div
                class="bulk-user-delete-confirmation__progress-line -{{entry.type}}"
              >
                {{entry.line}}
              </div>
            {{/each}}
            <div class="bulk-user-delete-confirmation__progress-anchor">
            </div>
          </div>
        {{else}}
          <p>{{i18n
              "admin.users.bulk_actions.delete.confirmation_modal.prompt_text"
              count=@model.userIds.length
              confirmation_phrase=this.confirmDeletePhrase
            }}
          </p>
          <input
            class="confirmation-phrase"
            type="text"
            placeholder={{this.confirmDeletePhrase}}
            {{on "input" this.onPromptInput}}
          />
        {{/if}}
      </:body>
      <:footer>
        <DButton
          class="confirm-delete btn-danger"
          @icon="trash-can"
          @label="admin.users.bulk_actions.delete.confirmation_modal.confirm"
          @disabled={{this.confirmButtonDisabled}}
          @action={{this.startDelete}}
        />
        <DButton
          class="btn-default"
          @label="admin.users.bulk_actions.delete.confirmation_modal.close"
          @action={{this.closeModal}}
        />
      </:footer>
    </DModal>
  </template>
}
