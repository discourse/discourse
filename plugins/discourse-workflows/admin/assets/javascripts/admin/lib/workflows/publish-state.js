import { tracked } from "@glimmer/tracking";
import { ajax } from "discourse/lib/ajax";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";

export default class WorkflowPublishState {
  #workflow;
  #dialog;

  #onDiscard;
  @tracked _publishedOverride = null;
  @tracked _hasUnpublishedChangesOverride = null;

  constructor({ workflow, dialog, onDiscard }) {
    this.#workflow = workflow;
    this.#dialog = dialog;
    this.#onDiscard = onDiscard;
  }

  get published() {
    return this._publishedOverride ?? Boolean(this.#workflow.activeVersionId);
  }

  get hasUnpublishedChanges() {
    return (
      this._hasUnpublishedChangesOverride ??
      Boolean(this.#workflow.hasUnpublishedChanges)
    );
  }

  get publishDisabled() {
    return this.published && !this.hasUnpublishedChanges;
  }

  get visible() {
    return !this.publishDisabled;
  }

  get showDiscardButton() {
    return this.published && this.hasUnpublishedChanges;
  }

  async publish() {
    this._publishedOverride = true;
    this._hasUnpublishedChangesOverride = false;
    try {
      await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.#workflow.id}.json`,
        {
          type: "PUT",
          data: { workflow: { published: true } },
        }
      );
      this.#workflow.activeVersionId = this.#workflow.versionId;
      this.#workflow.hasUnpublishedChanges = false;
      this._publishedOverride = null;
      this._hasUnpublishedChangesOverride = null;
    } catch (e) {
      this._publishedOverride = null;
      this._hasUnpublishedChangesOverride = null;
      popupAjaxError(e);
    }
  }

  async discard() {
    const confirmed = await this.#dialog.confirm({
      message: i18n("discourse_workflows.discard_changes_confirmation"),
      confirmButtonLabel: "discourse_workflows.discard_changes",
      cancelButtonLabel: "discourse_workflows.keep_editing",
    });

    if (!confirmed) {
      return;
    }

    this._hasUnpublishedChangesOverride = false;

    try {
      const response = await ajax(
        `/admin/plugins/discourse-workflows/workflows/${this.#workflow.id}/discard-draft.json`,
        { type: "POST" }
      );
      this.#workflow.setProperties({
        name: response.workflow.name,
        nodes: response.workflow.nodes || [],
        connections: response.workflow.connections || {},
        versionId: response.workflow.version_id,
        activeVersionId: response.workflow.active_version_id,
        versionCounter: response.workflow.version_counter,
        hasUnpublishedChanges: response.workflow.has_unpublished_changes,
        settings: response.workflow.settings || {},
        settingFields: response.workflow.setting_fields || [],
        timezone: response.workflow.timezone,
        staticData: response.workflow.static_data || {},
        pinData: response.workflow.pin_data || {},
      });
      this._hasUnpublishedChangesOverride = null;
      this.#onDiscard?.(response.workflow);
    } catch (e) {
      this._hasUnpublishedChangesOverride = null;
      popupAjaxError(e);
    }
  }
}
