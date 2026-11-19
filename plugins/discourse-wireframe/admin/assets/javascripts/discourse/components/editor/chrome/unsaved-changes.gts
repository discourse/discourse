import Component from "@glimmer/component";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type DialogService from "discourse/dialog-holder/services/dialog";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import type WireframeLayoutStatusService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-status";

/**
 * What the Save button would save: "All changes saved" when nothing is pending,
 * otherwise how many unsaved changes there are, with a way to discard them.
 */
export default class UnsavedChanges extends Component {
  @service declare dialog: DialogService;
  @service declare wireframeLayoutStatus: WireframeLayoutStatusService;

  get label(): string {
    return i18n("wireframe.changes.count", {
      count: this.wireframeLayoutStatus.changes.length,
    });
  }

  get savedLabel(): string {
    return this.wireframeLayoutStatus.justSaved
      ? i18n("wireframe.changes.saved_just_now")
      : i18n("wireframe.changes.all_saved");
  }

  @action
  discard(): void {
    this.dialog.confirm({
      message: i18n("wireframe.changes.discard_confirm"),
      confirmButtonLabel: "wireframe.changes.discard",
      didConfirm: () => this.wireframeLayoutStatus.discard(),
    });
  }

  <template>
    {{#if this.wireframeLayoutStatus.hasUnsavedChanges}}
      <span class="wireframe-unsaved">
        <span class="wireframe-unsaved__label">
          <span aria-hidden="true" class="wireframe-unsaved__dot"></span>
          {{this.label}}
        </span>
        <DButton
          class="btn-flat btn-small wireframe-unsaved__discard"
          @action={{this.discard}}
          @label="wireframe.changes.discard"
        />
      </span>
    {{else}}
      <span class="wireframe-saved-state">{{this.savedLabel}}</span>
    {{/if}}
  </template>
}
