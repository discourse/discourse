// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import ConditionsTree from "./conditions-tree";
import InspectorContainerArgsForm from "./inspector-container-args-form";
import InspectorForm from "./inspector-form";
import InspectorLayoutForm from "./inspector-layout-form";
import InspectorMetadataSection from "./inspector-metadata-section";
import InspectorRawJson from "./inspector-raw-json";

/**
 * Inspector for the selected block. Phase 7p.5 reshape: replaces the
 * stacked-sections layout with a tab strip (Args / Conditions / Raw
 * JSON). Metadata moves to a small `ⓘ` button next to the block name,
 * surfacing via a tooltip — it's reference info, not edit info, and
 * doesn't deserve its own pane.
 */
export default class InspectorPanel extends Component {
  @service wireframe;

  isTabActive = (tab) => this._activeTab === tab;
  @tracked _activeTab = "args";

  get hasSelection() {
    return this.wireframe.selectedBlockData != null;
  }

  get data() {
    return this.wireframe.selectedBlockData;
  }

  get metadata() {
    return this.data?.metadata ?? null;
  }

  /**
   * Whether the inspector should render the editable form. True if either
   * the block declared an `args` schema OR the layout passes any args at
   * runtime (in which case `InspectorForm` falls back to an inferred
   * schema). Blocks with no schema and no args still show "no arguments".
   */
  get hasArgsSchema() {
    const declaredArgs = this.metadata?.args;
    if (declaredArgs && Object.keys(declaredArgs).length > 0) {
      return true;
    }
    const liveArgs = this.data?.args;
    return !!(liveArgs && Object.keys(liveArgs).length > 0);
  }

  /**
   * Whether the selected block deserves a bespoke args form instead of
   * the generic FormKit one. The `wf:layout` block gets a custom form
   * (Phase 7s.4) that surfaces mode-specific controls — segmented
   * mode picker, columns/rows steppers, gap slider, template
   * disclosure. Other blocks fall through to the generic form.
   *
   * @returns {boolean}
   */
  get hasCustomLayoutForm() {
    return this.data?.name === "wf:layout";
  }

  /**
   * Whether the selected entry should render a placement form. True when
   * its parent declares a `childArgs` schema — for the current visual
   * editor that's the `wf:layout` block, so direct children of a grid /
   * stack / row layout get an extra inspector section to edit their
   * `containerArgs.<mode>` placement hints.
   *
   * @returns {boolean}
   */
  get hasContainerArgsForm() {
    return this.data?.parentChildArgsSchema != null;
  }

  /**
   * Combined block-info string shown in the metadata tooltip. Keeps
   * three-line trivia (namespace, description, container flag) out of
   * the main pane.
   */
  get metadataTooltip() {
    const parts = [];
    if (this.metadata?.namespace) {
      parts.push(
        `${i18n("wireframe.inspector.label_namespace")}: ${this.metadata.namespace}`
      );
    }
    if (this.metadata?.description) {
      parts.push(this.metadata.description);
    }
    parts.push(
      `${i18n("wireframe.inspector.label_is_container")}: ${
        this.metadata?.isContainer ? "yes" : "no"
      }`
    );
    return parts.join("\n");
  }

  /**
   * Whether the Args tab contains validation errors and should render
   * the warning badge on its tab button. Today every structured detail
   * we emit is either field-attributed (under an arg) or block-level
   * (constraints, structural). Both belong to Args content, so the
   * Args tab badges when either bucket is non-empty.
   *
   * Conditions / Raw JSON tabs don't badge yet — the validator doesn't
   * attribute condition errors to a `condition` scope, and Raw JSON is
   * read-only.
   *
   * @returns {boolean}
   */
  get argsTabHasErrors() {
    return this.wireframe.selectedBlockHasErrors;
  }

  @action
  setTab(tab) {
    this._activeTab = tab;
  }

  @action
  toggleDetachConditions() {
    this.wireframe.toggleConditionsDetached();
  }

  <template>
    {{#if this.hasSelection}}
      <div class="wireframe-inspector__header">
        <span class="wireframe-inspector__block-name">
          {{this.data.name}}
        </span>
        <span
          class="wireframe-inspector__metadata-info"
          title={{this.metadataTooltip}}
          aria-label={{this.metadataTooltip}}
        >
          {{dIcon "circle-info"}}
        </span>
      </div>

      <InspectorMetadataSection />

      <div class="wireframe-inspector__tabs" role="tablist">
        <DButton
          class={{dConcatClass
            "btn-flat wireframe-inspector__tab"
            (if (this.isTabActive "args") "--active")
            (if this.argsTabHasErrors "--has-errors")
          }}
          @label="wireframe.inspector.tab_args"
          @icon={{if this.argsTabHasErrors "triangle-exclamation"}}
          @action={{fn this.setTab "args"}}
        />
        <DButton
          class={{dConcatClass
            "btn-flat wireframe-inspector__tab"
            (if (this.isTabActive "conditions") "--active")
          }}
          @label="wireframe.inspector.tab_conditions"
          @action={{fn this.setTab "conditions"}}
        />
        <DButton
          class={{dConcatClass
            "btn-flat wireframe-inspector__tab"
            (if (this.isTabActive "raw") "--active")
          }}
          @label="wireframe.inspector.tab_raw"
          @action={{fn this.setTab "raw"}}
        />
      </div>

      <div class="wireframe-inspector__body">
        {{#if (this.isTabActive "args")}}
          {{#if this.hasCustomLayoutForm}}
            <InspectorLayoutForm />
          {{else if this.hasArgsSchema}}
            <InspectorForm />
          {{else}}
            <div class="panel-empty">
              {{i18n "wireframe.inspector.label_no_args"}}
            </div>
          {{/if}}
          {{#if this.hasContainerArgsForm}}
            <InspectorContainerArgsForm />
          {{/if}}
        {{else if (this.isTabActive "conditions")}}
          <div class="wireframe-inspector__conditions-header">
            <DButton
              class="btn-flat wireframe-inspector__detach-btn"
              @icon={{if
                this.wireframe.conditionsDetached
                "down-left-and-up-right-to-center"
                "up-right-and-down-left-from-center"
              }}
              @label={{if
                this.wireframe.conditionsDetached
                "wireframe.inspector.conditions.redock_panel"
                "wireframe.inspector.conditions.detach_panel"
              }}
              @title="wireframe.inspector.conditions.detach_panel"
              @action={{this.toggleDetachConditions}}
            />
          </div>
          {{#if this.wireframe.conditionsDetached}}
            <p class="wireframe-inspector__conditions-stub">
              {{i18n "wireframe.inspector.conditions.detached_stub"}}
            </p>
          {{else}}
            <ConditionsTree />
          {{/if}}
        {{else}}
          <InspectorRawJson />
        {{/if}}
      </div>
    {{else}}
      <div class="panel-empty">{{i18n "wireframe.inspector.empty"}}</div>
    {{/if}}
  </template>
}
