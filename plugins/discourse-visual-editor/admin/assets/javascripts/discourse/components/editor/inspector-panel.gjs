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
  @service visualEditor;

  isTabActive = (tab) => this._activeTab === tab;
  @tracked _activeTab = "args";

  get hasSelection() {
    return this.visualEditor.selectedBlockData != null;
  }

  get data() {
    return this.visualEditor.selectedBlockData;
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
   * the generic FormKit one. The `ve:layout` block gets a custom form
   * (Phase 7s.4) that surfaces mode-specific controls — segmented
   * mode picker, columns/rows steppers, gap slider, template
   * disclosure. Other blocks fall through to the generic form.
   *
   * @returns {boolean}
   */
  get hasCustomLayoutForm() {
    return this.data?.name === "ve:layout";
  }

  /**
   * Whether the selected entry should render a placement form. True when
   * its parent declares a `childArgs` schema — for the current visual
   * editor that's the `ve:layout` block, so direct children of a grid /
   * stack / row layout get an extra inspector section to edit their
   * `containerArgs.<mode>` placement hints.
   *
   * @returns {boolean}
   */
  get hasContainerArgsForm() {
    return this.data?.parentChildArgsSchema != null;
  }

  /**
   * The selected block's soft-failure marker, read directly from the
   * entry's `__failureType` / `__failureReason` (set by the validator
   * when running in permissive mode). Drives the inline warning banner
   * and recovery action buttons.
   *
   * @returns {{failureType: string, failureReason: string}|null}
   */
  get failure() {
    return this.visualEditor.selectedBlockFailure;
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
        `${i18n("visual_editor.inspector.label_namespace")}: ${this.metadata.namespace}`
      );
    }
    if (this.metadata?.description) {
      parts.push(this.metadata.description);
    }
    parts.push(
      `${i18n("visual_editor.inspector.label_is_container")}: ${
        this.metadata?.isContainer ? "yes" : "no"
      }`
    );
    return parts.join("\n");
  }

  @action
  setTab(tab) {
    this._activeTab = tab;
  }

  @action
  removeSelectedBlock() {
    if (this.data?.key) {
      this.visualEditor.removeBlock(this.data.key);
    }
  }

  @action
  toggleDetachConditions() {
    this.visualEditor.toggleConditionsDetached();
  }

  <template>
    {{#if this.hasSelection}}
      {{#if this.failure}}
        <div class="visual-editor-inspector-warning" role="alert">
          <span class="visual-editor-inspector-warning__header">
            {{dIcon "triangle-exclamation"}}
            <span>{{i18n "visual_editor.inspector.warning_header"}}</span>
          </span>
          {{#if this.failure.failureReason}}
            <p class="visual-editor-inspector-warning__reason">
              {{this.failure.failureReason}}
            </p>
          {{/if}}
          <div class="visual-editor-inspector-warning__actions">
            <DButton
              class="btn-danger"
              @icon="trash-can"
              @label="visual_editor.inspector.remove_block_action"
              @action={{this.removeSelectedBlock}}
            />
          </div>
        </div>
      {{/if}}

      <div class="visual-editor-inspector__header">
        <span class="visual-editor-inspector__block-name">
          {{this.data.name}}
        </span>
        <span
          class="visual-editor-inspector__metadata-info"
          title={{this.metadataTooltip}}
          aria-label={{this.metadataTooltip}}
        >
          {{dIcon "circle-info"}}
        </span>
      </div>

      <InspectorMetadataSection />

      <div class="visual-editor-inspector__tabs" role="tablist">
        <DButton
          class={{dConcatClass
            "btn-flat visual-editor-inspector__tab"
            (if (this.isTabActive "args") "--active")
          }}
          @label="visual_editor.inspector.tab_args"
          @action={{fn this.setTab "args"}}
        />
        <DButton
          class={{dConcatClass
            "btn-flat visual-editor-inspector__tab"
            (if (this.isTabActive "conditions") "--active")
          }}
          @label="visual_editor.inspector.tab_conditions"
          @action={{fn this.setTab "conditions"}}
        />
        <DButton
          class={{dConcatClass
            "btn-flat visual-editor-inspector__tab"
            (if (this.isTabActive "raw") "--active")
          }}
          @label="visual_editor.inspector.tab_raw"
          @action={{fn this.setTab "raw"}}
        />
      </div>

      <div class="visual-editor-inspector__body">
        {{#if (this.isTabActive "args")}}
          {{#if this.hasCustomLayoutForm}}
            <InspectorLayoutForm />
          {{else if this.hasArgsSchema}}
            <InspectorForm />
          {{else}}
            <div class="panel-empty">
              {{i18n "visual_editor.inspector.label_no_args"}}
            </div>
          {{/if}}
          {{#if this.hasContainerArgsForm}}
            <InspectorContainerArgsForm />
          {{/if}}
        {{else if (this.isTabActive "conditions")}}
          <div class="visual-editor-inspector__conditions-header">
            <DButton
              class="btn-flat visual-editor-inspector__detach-btn"
              @icon={{if
                this.visualEditor.conditionsDetached
                "down-left-and-up-right-to-center"
                "up-right-and-down-left-from-center"
              }}
              @label={{if
                this.visualEditor.conditionsDetached
                "visual_editor.inspector.conditions.redock_panel"
                "visual_editor.inspector.conditions.detach_panel"
              }}
              @title="visual_editor.inspector.conditions.detach_panel"
              @action={{this.toggleDetachConditions}}
            />
          </div>
          {{#if this.visualEditor.conditionsDetached}}
            <p class="visual-editor-inspector__conditions-stub">
              {{i18n "visual_editor.inspector.conditions.detached_stub"}}
            </p>
          {{else}}
            <ConditionsTree />
          {{/if}}
        {{else}}
          <InspectorRawJson />
        {{/if}}
      </div>
    {{else}}
      <div class="panel-empty">{{i18n "visual_editor.inspector.empty"}}</div>
    {{/if}}
  </template>
}
