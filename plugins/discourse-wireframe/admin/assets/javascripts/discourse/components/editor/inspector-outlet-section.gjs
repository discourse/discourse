// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { OUTLET_STATE } from "../../services/wireframe";

/**
 * The per-outlet section shown in the inspector when an outlet root is
 * selected. Surfaces the outlet's state (read-only / default / published) plus
 * an editing pill, and the per-outlet verbs gated by that state:
 *
 * - Save draft / Publish — available whenever the outlet is editable; Publish
 *   is disabled for a Git-managed owner (export is a later phase).
 * - Reset to default — only when a theme field is published and not Git-managed.
 * - Discard changes — only when the outlet has unsaved edits.
 */
export default class InspectorOutletSection extends Component {
  @service wireframe;

  get state() {
    return this.wireframe.outletState(this.args.outletName);
  }

  get owner() {
    return this.wireframe.outletOwner(this.args.outletName);
  }

  get isEditing() {
    return this.wireframe.isOutletEditing(this.args.outletName);
  }

  get isEditable() {
    return this.state !== OUTLET_STATE.LOCKED;
  }

  get isPublished() {
    return this.state === OUTLET_STATE.PUBLISHED;
  }

  get canResetToDefault() {
    return this.isPublished && !this.owner.isGit;
  }

  <template>
    <section class="wireframe-inspector__outlet">
      <div class="wireframe-inspector__outlet-state">
        <span class={{concat "wireframe-outlet-badge --" this.state}}>{{i18n
            (concat "wireframe.outlet.state." this.state)
          }}</span>
        {{#if this.isEditing}}
          <span class="wireframe-outlet-badge --editing">{{i18n
              "wireframe.outlet.editing"
            }}</span>
        {{/if}}
      </div>

      {{#if this.isEditable}}
        <div class="wireframe-inspector__outlet-verbs">
          <DButton
            class="btn-default wireframe-outlet-verb__save-draft"
            @label="wireframe.outlet.save_draft"
            @action={{fn this.wireframe.saveDraftOutlet @outletName}}
          />
          <DButton
            class="btn-primary wireframe-outlet-verb__publish"
            @label="wireframe.outlet.publish"
            @disabled={{this.owner.isGit}}
            @title={{if
              this.owner.isGit
              (i18n "wireframe.outlet.publish_disabled_git")
            }}
            @action={{fn this.wireframe.publishOutlet @outletName}}
          />
          {{#if this.isEditing}}
            <DButton
              class="btn-default wireframe-outlet-verb__discard"
              @label="wireframe.outlet.discard"
              @action={{fn this.wireframe.discardOutlet @outletName}}
            />
          {{/if}}
          {{#if this.canResetToDefault}}
            <DButton
              class="btn-danger wireframe-outlet-verb__reset"
              @label="wireframe.outlet.reset_to_default"
              @action={{fn this.wireframe.resetToDefault @outletName}}
            />
          {{/if}}
        </div>
      {{/if}}
    </section>
  </template>
}
