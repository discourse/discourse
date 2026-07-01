// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { service } from "@ember/service";
import bodyClass from "discourse/helpers/body-class";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import dDragAndDropMonitor from "discourse/ui-kit/modifiers/d-drag-and-drop-monitor";
import { i18n } from "discourse-i18n";

const VE_DRAG_TYPES = ["wf-block", "wf-palette-block"];
import ActivityBar from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/activity-bar";
import BlockBreadcrumb from "discourse/plugins/discourse-wireframe/discourse/components/editor/chrome/block-breadcrumb";
import ConditionsFloatingPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/conditions-floating-panel";
import DropPreview from "discourse/plugins/discourse-wireframe/discourse/components/editor/drag-drop/drop-preview";
import InplaceTextController from "discourse/plugins/discourse-wireframe/discourse/components/editor/inplace/inplace-text-controller";
import InspectorPanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/inspector/inspector-panel";
import OutletJumpSelect from "discourse/plugins/discourse-wireframe/discourse/components/editor/outline/outlet-jump-select";
import OutlinePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/outline/outline-panel";
import PalettePanel from "discourse/plugins/discourse-wireframe/discourse/components/editor/palette/palette-panel";
import PublishBlockedCallout from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish/publish-blocked-callout";
import PublishReviewDrawer from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish/publish-review-drawer";
import PublishTargetIndicator from "discourse/plugins/discourse-wireframe/discourse/components/editor/publish/publish-target-indicator";
import SimulationControls from "discourse/plugins/discourse-wireframe/discourse/components/editor/simulation/simulation-controls";

// Persisted under core's global key-value store; the `wireframe_` prefix
// namespaces our keys within its shared `discourse_` bucket to avoid collisions.
const RIGHT_COLLAPSED_KEY = "wireframe_rightCollapsed";
const DIM_NON_EDITABLE_KEY = "wireframe_dimNonEditable";

/**
 * The 3-pane editor chrome (toolbar + outline + canvas + inspector).
 *
 * Mounted by the api-initializer when the editor is active. The canvas region
 * is intentionally a `pointer-events: none` placeholder — the live page
 * underneath handles all clicks; only block-chrome wrappers and the panels
 * receive editor input.
 */
export default class EditorShell extends Component {
  @service dragAndDrop;
  @service wireframeWorkspace;
  @service wireframeDragSession;
  @service wireframeDragDwell;
  @service wireframeMutationEngine;
  @service wireframeEditMode;
  @service wireframeRail;
  @service wireframeStaging;
  @service wireframeValidation;
  @service keyValueStore;

  @tracked warningsPanelOpen = false;
  @tracked rightCollapsed;
  @tracked dimNonEditable;

  constructor() {
    super(...arguments);
    // Hydrate persisted prefs in the constructor so `keyValueStore` is resolved.
    this.rightCollapsed =
      this.keyValueStore.getObject(RIGHT_COLLAPSED_KEY) ?? false;
    this.dimNonEditable =
      this.keyValueStore.getObject(DIM_NON_EDITABLE_KEY) ?? true;
  }

  /**
   * CSS classes for the shell. `--dragging` (set while a block drag is in flight)
   * lets editor-only affordances opt out of pointer events during a drag — e.g.
   * an empty container's call-to-action button, which would otherwise swallow the
   * drop instead of letting it land on the container's drop target.
   *
   * Rail collapse is NOT a shell class: the shell grid reads the `--wf-*-rail`
   * custom properties, which the `body` collapse classes (set via `bodyClass`
   * below) flip to the slim-strip width.
   */
  get shellClasses() {
    const classes = ["wireframe-shell"];
    if (this.dragAndDrop.isDragging) {
      classes.push("--dragging");
    }
    return classes.join(" ");
  }

  /**
   * The i18n key for the active left panel's header title. Mirrors the activity
   * bar's entry labels so the open panel and its rail entry read the same name.
   *
   * @returns {string}
   */
  get leftPanelTitleKey() {
    switch (this.wireframeRail.leftPanelTab) {
      case "outline":
        return "wireframe.chrome.panel_layers";
      case "issues":
        return "wireframe.chrome.panel_issues";
      default:
        return "wireframe.chrome.panel_add";
    }
  }

  @action
  toggleRightCollapsed() {
    this.rightCollapsed = !this.rightCollapsed;
    this.keyValueStore.setObject({
      key: RIGHT_COLLAPSED_KEY,
      value: this.rightCollapsed,
    });
  }

  @action
  toggleDimNonEditable() {
    this.dimNonEditable = !this.dimNonEditable;
    this.keyValueStore.setObject({
      key: DIM_NON_EDITABLE_KEY,
      value: this.dimNonEditable,
    });
  }

  @action
  toggleWarningsPanel() {
    this.warningsPanelOpen = !this.warningsPanelOpen;
  }

  @action
  exit() {
    this.wireframeWorkspace.exit();
  }

  @action
  undo() {
    this.wireframeMutationEngine.undo();
  }

  @action
  redo() {
    this.wireframeMutationEngine.redo();
  }

  <template>
    {{#if this.wireframeEditMode.active}}
      {{bodyClass
        "wireframe-active"
        (if this.wireframeRail.leftCollapsed "wireframe-active--left-collapsed")
        (if this.rightCollapsed "wireframe-active--right-collapsed")
        (if this.dimNonEditable "wireframe-active--dim-non-editable")
        (if this.wireframeDragSession.dragActive "wireframe-dragging")
      }}
      <div
        class={{this.shellClasses}}
        {{dDragAndDropAutoScroll target="window" types=VE_DRAG_TYPES}}
        {{dDragAndDropMonitor
          types=VE_DRAG_TYPES
          onDragStart=this.wireframeDragDwell.handleDragStart
          onDrag=this.wireframeDragDwell.handleDrag
          onDrop=this.wireframeDragDwell.handleDrop
        }}
      >
        {{! Mounts a ProseMirror editor over whichever in-place edit region is
            active. Rendered as a no-DOM controller — its only visible output
            is the editor it portals into the renderer's span. }}
        <InplaceTextController />
        <div class="wireframe-toolbar">
          <div class="toolbar-left">
            {{dIcon "wand-magic-sparkles"}}
            <span class="toolbar-title">Wireframe</span>
            <OutletJumpSelect />
          </div>
          <div class="toolbar-right">
            <SimulationControls />
            <DButton
              class={{dConcatClass
                "btn-flat wireframe-btn-dim"
                (if this.dimNonEditable "--active")
              }}
              @icon="circle-half-stroke"
              @title="wireframe.chrome.dim_non_editable_title"
              @action={{this.toggleDimNonEditable}}
            />
            {{#if this.wireframeValidation.hasValidationWarnings}}
              <DButton
                class={{dConcatClass
                  "btn-flat wireframe-btn-warnings"
                  (if this.warningsPanelOpen "--open")
                }}
                @icon="triangle-exclamation"
                @translatedLabel={{this.wireframeValidation.validationWarnings.length}}
                @title="wireframe.chrome.warnings_button_title"
                @action={{this.toggleWarningsPanel}}
              />
            {{/if}}
            <DButton
              class="wireframe-btn-undo"
              @icon="arrow-rotate-left"
              @title="wireframe.chrome.undo"
              @disabled={{if this.wireframeMutationEngine.canUndo false true}}
              @action={{this.undo}}
            />
            <DButton
              class="wireframe-btn-redo"
              @icon="arrow-rotate-right"
              @title="wireframe.chrome.redo"
              @disabled={{if this.wireframeMutationEngine.canRedo false true}}
              @action={{this.redo}}
            />
            <PublishTargetIndicator />
            <DButton
              class="btn-primary wireframe-btn-save"
              @icon="cloud-arrow-up"
              @label="wireframe.review.open"
              @disabled={{unless this.wireframeStaging.canOpenReview true}}
              @action={{this.wireframeStaging.openReviewDrawer}}
            />
            <DButton
              @icon="xmark"
              @label="wireframe.chrome.exit"
              @action={{this.exit}}
            />
          </div>
        </div>

        <PublishBlockedCallout />

        {{#if this.warningsPanelOpen}}
          <div class="wireframe-warnings-panel" role="region">
            <div class="wireframe-warnings-panel__header">
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n
                  "wireframe.chrome.warnings_panel_title"
                  count=this.wireframeValidation.validationWarnings.length
                }}</span>
            </div>
            <ul class="wireframe-warnings-panel__list">
              {{#each this.wireframeValidation.validationWarnings as |w|}}
                <li>
                  <code>{{w.outletName}}</code>
                  <span>{{w.message}}</span>
                </li>
              {{/each}}
            </ul>
          </div>
        {{/if}}

        <ActivityBar />

        {{! The wide left panel is rendered ONLY when expanded; the activity bar
            is the persistent collapsed state. Rendering it at zero width instead
            would mount a clipped header and paint a stray border seam. }}
        {{#unless this.wireframeRail.leftCollapsed}}
          <div class="wireframe-panel --left">
            <div class="panel-header">
              <span>{{i18n this.leftPanelTitleKey}}</span>
            </div>
            <div class="panel-body">
              {{#if (this.wireframeRail.isLeftPanelTabActive "palette")}}
                <PalettePanel />
              {{else if (this.wireframeRail.isLeftPanelTabActive "outline")}}
                <OutlinePanel />
              {{else if (this.wireframeRail.isLeftPanelTabActive "issues")}}
                <div
                  class="wireframe-issues"
                  role="region"
                  aria-label={{i18n "wireframe.chrome.panel_issues"}}
                >
                  <div class="panel-empty">
                    {{i18n "wireframe.chrome.issues_empty"}}
                  </div>
                </div>
              {{/if}}
            </div>
          </div>
        {{/unless}}

        <div class="wireframe-canvas">
          <BlockBreadcrumb />
        </div>

        <div
          class={{dConcatClass
            "wireframe-panel"
            "--right"
            (if this.rightCollapsed "--collapsed")
          }}
        >
          <div class="panel-header">
            <DButton
              class="btn-flat panel-collapse-toggle"
              @icon={{if this.rightCollapsed "chevron-left" "chevron-right"}}
              @title={{if
                this.rightCollapsed
                "wireframe.chrome.expand_panel"
                "wireframe.chrome.collapse_panel"
              }}
              @ariaLabel={{if
                this.rightCollapsed
                "wireframe.chrome.expand_panel"
                "wireframe.chrome.collapse_panel"
              }}
              @action={{this.toggleRightCollapsed}}
            />
            {{#unless this.rightCollapsed}}
              <span>{{i18n "wireframe.chrome.panel_inspector"}}</span>
            {{/unless}}
          </div>
          {{#unless this.rightCollapsed}}
            <div class="panel-body">
              <InspectorPanel />
            </div>
          {{/unless}}
        </div>
      </div>

      <ConditionsFloatingPanel />
      <DropPreview />
      <PublishReviewDrawer />
    {{/if}}
  </template>
}
