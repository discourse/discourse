import Component from "@glimmer/component";
import { concat } from "@ember/helper";
import { service } from "@ember/service";
import { i18n } from "discourse-i18n";
import WireframeLayoutQueryService, {
  OUTLET_STATE,
} from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";
import type WireframePublishTargetService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-publish-target";

interface InspectorOutletSectionSignature {
  /** Selected outlet identity. */
  Args: {
    /** Identifier of the selected outlet. */
    outletName: string;
  };
}

/**
 * The per-outlet section shown in the inspector when an outlet root is selected.
 * Surfaces the outlet's status in one badge — "Editing" while it has unsaved
 * edits, otherwise its state (read-only / default / published, with the owning
 * theme named so an override is trackable).
 *
 * The save, publish, and theme escape-hatch verbs once shown here now live in the
 * publish review surface, which presents them grouped by target theme; this
 * section is read-only status only.
 */
export default class InspectorOutletSection extends Component<InspectorOutletSectionSignature> {
  /** Reports whether the selected outlet has unsaved mutations. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;
  /** Resolves the selected outlet's persistence state. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;
  /** Resolves the theme owning the selected outlet. */
  @service declare wireframePublishTarget: WireframePublishTargetService;

  /** Persistence state of the selected outlet. */
  get state(): string {
    return this.wireframeLayoutQuery.outletState(this.args.outletName);
  }

  /** Whether the selected outlet has unsaved edits. */
  get isEditing(): boolean {
    return this.wireframeMutationEngine.isOutletEdited(this.args.outletName);
  }

  /** Whether the selected outlet is owned by a published theme field. */
  get isPublished(): boolean {
    return this.state === OUTLET_STATE.PUBLISHED;
  }

  /**
   * The owning theme's name, shown on the published badge so an override (a
   * component owning the outlet over its parent) is visible.
   *
   */
  get ownerName(): string | null {
    return this.wireframePublishTarget.outletOwner(this.args.outletName)
      .themeName;
  }

  <template>
    <section class="wireframe-inspector__outlet">
      <div class="wireframe-inspector__outlet-state">
        {{! One badge: "Editing" supersedes the base state so the two are never
          shown together. }}
        <span
          class={{concat
            "wireframe-outlet-badge --"
            (if this.isEditing "editing" this.state)
          }}
        >
          {{#if this.isEditing}}
            {{i18n "wireframe.outlet.editing"}}
          {{else if (if this.isPublished this.ownerName)}}
            {{i18n "wireframe.outlet.published_by" theme=this.ownerName}}
          {{else}}
            {{i18n (concat "wireframe.outlet.state." this.state)}}
          {{/if}}
        </span>
      </div>
    </section>
  </template>
}
