import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import routeAction from "discourse/helpers/route-action";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class AdminBackupsActions extends Component {
  @service currentUser;
  @service site;
  @service dialog;

  get rollbackDisabled() {
    return !this.rollbackEnabled;
  }

  get rollbackEnabled() {
    return (
      this.args.backups.canRollback &&
      this.args.backups.restoreEnabled &&
      !this.args.backups.isOperationRunning
    );
  }

  @action
  toggleReadOnlyMode() {
    if (!this.site.isReadOnly) {
      this.dialog.yesNoConfirm({
        message: i18n("admin.backups.read_only.enable.confirm"),
        didConfirm: () => {
          this.currentUser.set("hideReadOnlyAlert", true);
          this.#toggleReadOnlyMode(true);
        },
      });
    } else {
      this.#toggleReadOnlyMode(false);
    }
  }

  async #toggleReadOnlyMode(enable) {
    try {
      await ajax("/admin/backups/readonly", {
        type: "PUT",
        data: { enable },
      });
      this.site.set("isReadOnly", enable);
    } catch (err) {
      popupAjaxError(err);
    }
  }

  <template>
    {{#if @backups.isOperationRunning}}
      <@actions.Danger
        class="admin-backups__cancel"
        @action={{routeAction "cancelOperation"}}
        @icon="xmark"
        @label="admin.backups.operations.cancel.label"
        @title="admin.backups.operations.cancel.title"
      />
    {{else}}
      <@actions.Primary
        class="admin-backups__start"
        @action={{routeAction "showStartBackupModal"}}
        @icon="rocket"
        @label="admin.backups.operations.backup.label"
        @title="admin.backups.operations.backup.title"
      />
    {{/if}}

    {{#if @backups.canRollback}}
      <@actions.Default
        class="admin-backups__rollback"
        @action={{routeAction "rollback"}}
        @disabled={{this.rollbackDisabled}}
        @icon="truck-medical"
        @label="admin.backups.operations.rollback.label"
        @title="admin.backups.operations.rollback.title"
      />
    {{/if}}

    <@actions.Default
      class="admin-backups__toggle-read-only"
      @action={{this.toggleReadOnlyMode}}
      @disabled={{@backups.isOperationRunning}}
      @icon={{if this.site.isReadOnly "far-eye-slash" "far-eye"}}
      @label={{if
        this.site.isReadOnly
        "admin.backups.read_only.disable.label"
        "admin.backups.read_only.enable.label"
      }}
      @title={{if
        this.site.isReadOnly
        "admin.backups.read_only.disable.title"
        "admin.backups.read_only.enable.title"
      }}
    />
  </template>
}
