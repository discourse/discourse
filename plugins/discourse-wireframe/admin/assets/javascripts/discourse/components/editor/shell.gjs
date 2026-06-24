// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import dDragAndDropAutoScroll from "discourse/ui-kit/modifiers/d-drag-and-drop-auto-scroll";
import { i18n } from "discourse-i18n";

const VE_DRAG_TYPES = ["wf-block", "wf-palette-block"];
import BlockBreadcrumb from "./block-breadcrumb";
import ConditionsFloatingPanel from "./conditions-floating-panel";
import DropPreview from "./drop-preview";
import InlineEditController from "./inline-edit-controller";
import InspectorPanel from "./inspector-panel";
import OutletJumpSelect from "./outlet-jump-select";
import OutlinePanel from "./outline-panel";
import PalettePanel from "./palette-panel";
import PublishBlockedCallout from "./publish-blocked-callout";
import PublishReviewDrawer from "./publish-review-drawer";
import PublishTargetIndicator from "./publish-target-indicator";
import SimulationControls from "./simulation-controls";

/**
 * The 3-pane editor chrome (toolbar + outline + canvas + inspector).
 *
 * Mounted by the api-initializer when the editor is active. The canvas region
 * is intentionally a `pointer-events: none` placeholder — the live page
 * underneath handles all clicks; only block-chrome wrappers and the panels
 * receive editor input.
 */
export default class EditorShell extends Component {
  @service wireframe;

  @tracked warningsPanelOpen = false;
  @tracked leftPanelTab = "palette";
  @tracked leftCollapsed = readBoolStorage("ve.leftCollapsed");
  @tracked rightCollapsed = readBoolStorage("ve.rightCollapsed");
  @tracked dimNonEditable = readBoolStorage("ve.dimNonEditable", true);

  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  /**
   * CSS classes for the shell that drive the canvas grid template
   * (`--left-collapsed` / `--right-collapsed` from
   * `wireframe.scss` adjust `grid-template-columns`).
   */
  get shellClasses() {
    const classes = ["wireframe-shell"];
    if (this.leftCollapsed) {
      classes.push("--left-collapsed");
    }
    if (this.rightCollapsed) {
      classes.push("--right-collapsed");
    }
    return classes.join(" ");
  }

  @action
  setLeftPanelTab(tab) {
    this.leftPanelTab = tab;
  }

  @action
  toggleLeftCollapsed() {
    this.leftCollapsed = !this.leftCollapsed;
    writeBoolStorage("ve.leftCollapsed", this.leftCollapsed);
    this.#syncBodyClasses();
  }

  @action
  toggleRightCollapsed() {
    this.rightCollapsed = !this.rightCollapsed;
    writeBoolStorage("ve.rightCollapsed", this.rightCollapsed);
    this.#syncBodyClasses();
  }

  @action
  toggleDimNonEditable() {
    this.dimNonEditable = !this.dimNonEditable;
    writeBoolStorage("ve.dimNonEditable", this.dimNonEditable);
    this.#syncBodyClasses();
  }

  /**
   * Mirrors the collapsed-rail state onto `body` so the underlying
   * page's `padding-left` / `padding-right` (set by
   * `body.wireframe-active`) can shrink to match. Driven by
   * `body.wireframe-active.--left-collapsed` / `.--right-collapsed`
   * CSS rules.
   */
  @action
  setupBodyClasses() {
    this.#syncBodyClasses();
  }

  @action
  toggleWarningsPanel() {
    this.warningsPanelOpen = !this.warningsPanelOpen;
  }

  @action
  exit() {
    this.wireframe.exit();
  }

  @action
  undo() {
    this.wireframe.undo();
  }

  @action
  redo() {
    this.wireframe.redo();
  }

  #syncBodyClasses() {
    document.body.classList.toggle(
      "wireframe-active--left-collapsed",
      this.leftCollapsed
    );
    document.body.classList.toggle(
      "wireframe-active--right-collapsed",
      this.rightCollapsed
    );
    document.body.classList.toggle(
      "wireframe-active--dim-non-editable",
      this.dimNonEditable
    );
  }

  <template>
    {{#if this.wireframe.isActive}}
      <div
        class={{this.shellClasses}}
        {{didInsert this.setupBodyClasses}}
        {{dDragAndDropAutoScroll target="window" types=VE_DRAG_TYPES}}
      >
        {{! Mounts a ProseMirror editor over whichever inline-edit region is
            active. Rendered as a no-DOM controller — its only visible output
            is the editor it portals into the renderer's span. }}
        <InlineEditController />
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
            {{#if this.wireframe.hasValidationWarnings}}
              <DButton
                class={{dConcatClass
                  "btn-flat wireframe-btn-warnings"
                  (if this.warningsPanelOpen "--open")
                }}
                @icon="triangle-exclamation"
                @translatedLabel={{this.wireframe.validationWarnings.length}}
                @title="wireframe.chrome.warnings_button_title"
                @action={{this.toggleWarningsPanel}}
              />
            {{/if}}
            <DButton
              class="wireframe-btn-undo"
              @icon="arrow-rotate-left"
              @title="wireframe.chrome.undo"
              @disabled={{if this.wireframe.canUndo false true}}
              @action={{this.undo}}
            />
            <DButton
              class="wireframe-btn-redo"
              @icon="arrow-rotate-right"
              @title="wireframe.chrome.redo"
              @disabled={{if this.wireframe.canRedo false true}}
              @action={{this.redo}}
            />
            <PublishTargetIndicator />
            <DButton
              class="btn-primary wireframe-btn-save"
              @icon="cloud-arrow-up"
              @label="wireframe.review.open"
              @disabled={{unless this.wireframe.canOpenReview true}}
              @action={{this.wireframe.openReviewDrawer}}
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
                  count=this.wireframe.validationWarnings.length
                }}</span>
            </div>
            <ul class="wireframe-warnings-panel__list">
              {{#each this.wireframe.validationWarnings as |w|}}
                <li>
                  <code>{{w.outletName}}</code>
                  <span>{{w.message}}</span>
                </li>
              {{/each}}
            </ul>
          </div>
        {{/if}}

        <div
          class={{dConcatClass
            "wireframe-panel"
            "--left"
            (if this.leftCollapsed "--collapsed")
          }}
        >
          <div class="panel-header panel-header--tabs">
            {{#unless this.leftCollapsed}}
              <DButton
                class={{dConcatClass
                  "btn-flat panel-tab"
                  (if (this.isLeftPanelTabActive "palette") "--active")
                }}
                @label="wireframe.chrome.tab_palette"
                @action={{fn this.setLeftPanelTab "palette"}}
              />
              <DButton
                class={{dConcatClass
                  "btn-flat panel-tab"
                  (if (this.isLeftPanelTabActive "outline") "--active")
                }}
                @label="wireframe.chrome.tab_outline"
                @action={{fn this.setLeftPanelTab "outline"}}
              />
            {{/unless}}
            <DButton
              class="btn-flat panel-collapse-toggle"
              @icon={{if this.leftCollapsed "chevron-right" "chevron-left"}}
              @title={{if
                this.leftCollapsed
                "wireframe.chrome.expand_panel"
                "wireframe.chrome.collapse_panel"
              }}
              @ariaLabel={{if
                this.leftCollapsed
                "wireframe.chrome.expand_panel"
                "wireframe.chrome.collapse_panel"
              }}
              @action={{this.toggleLeftCollapsed}}
            />
          </div>
          {{#unless this.leftCollapsed}}
            <div class="panel-body">
              {{#if (this.isLeftPanelTabActive "palette")}}
                <PalettePanel />
              {{else}}
                <OutlinePanel />
              {{/if}}
            </div>
          {{/unless}}
        </div>

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

/**
 * Reads a boolean preference from `localStorage`. Swallows access
 * exceptions (private browsing, strict cookie settings) and returns
 * `false`, so the editor degrades to "expanded" when storage isn't
 * usable.
 *
 * @param {string} key
 * @returns {boolean}
 */
function readBoolStorage(key, defaultValue = false) {
  try {
    const v = localStorage.getItem(key);
    if (v === null) {
      return defaultValue;
    }
    return v === "true";
  } catch {
    return defaultValue;
  }
}

/**
 * Persists a boolean preference. Same swallow-and-no-op fallback as
 * the reader.
 *
 * @param {string} key
 * @param {boolean} value
 */
function writeBoolStorage(key, value) {
  try {
    localStorage.setItem(key, value ? "true" : "false");
  } catch {
    /* no-op */
  }
}
