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

const VE_DRAG_TYPES = ["ve-block", "ve-palette-block"];
import BlockBreadcrumb from "./block-breadcrumb";
import ConditionsFloatingPanel from "./conditions-floating-panel";
import DropPreview from "./drop-preview";
import InlineEditController from "./inline-edit-controller";
import InspectorPanel from "./inspector-panel";
import OutletJumpSelect from "./outlet-jump-select";
import OutlinePanel from "./outline-panel";
import PalettePanel from "./palette-panel";
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
  @service dialog;
  @service visualEditor;
  @service visualEditorPersistence;

  /**
   * In-flight Save state. Toggling this true grays out the Save button so a
   * user can't double-tap it while we're awaiting the server. Failures are
   * surfaced as a banner row beneath the toolbar (see `saveErrorMessage`).
   */
  @tracked isSaving = false;
  @tracked saveErrorMessage = null;
  @tracked warningsPanelOpen = false;
  @tracked leftPanelTab = "palette";
  @tracked leftCollapsed = readBoolStorage("ve.leftCollapsed");
  @tracked rightCollapsed = readBoolStorage("ve.rightCollapsed");

  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  @action
  setLeftPanelTab(tab) {
    this.leftPanelTab = tab;
  }

  @action
  toggleLeftCollapsed() {
    this.leftCollapsed = !this.leftCollapsed;
    writeBoolStorage("ve.leftCollapsed", this.leftCollapsed);
    this._syncBodyClasses();
  }

  @action
  toggleRightCollapsed() {
    this.rightCollapsed = !this.rightCollapsed;
    writeBoolStorage("ve.rightCollapsed", this.rightCollapsed);
    this._syncBodyClasses();
  }

  /**
   * Mirrors the collapsed-rail state onto `body` so the underlying
   * page's `padding-left` / `padding-right` (set by
   * `body.visual-editor-active`) can shrink to match. Driven by
   * `body.visual-editor-active.--left-collapsed` / `.--right-collapsed`
   * CSS rules.
   */
  @action
  setupBodyClasses() {
    this._syncBodyClasses();
  }

  _syncBodyClasses() {
    document.body.classList.toggle(
      "visual-editor-active--left-collapsed",
      this.leftCollapsed
    );
    document.body.classList.toggle(
      "visual-editor-active--right-collapsed",
      this.rightCollapsed
    );
  }

  /**
   * CSS classes for the shell that drive the canvas grid template
   * (`--left-collapsed` / `--right-collapsed` from
   * `visual-editor.scss` adjust `grid-template-columns`).
   */
  get shellClasses() {
    const classes = ["visual-editor-shell"];
    if (this.leftCollapsed) {
      classes.push("--left-collapsed");
    }
    if (this.rightCollapsed) {
      classes.push("--right-collapsed");
    }
    return classes.join(" ");
  }

  @action
  dismissSaveError() {
    this.saveErrorMessage = null;
  }

  @action
  toggleWarningsPanel() {
    this.warningsPanelOpen = !this.warningsPanelOpen;
  }

  @action
  exit() {
    this.visualEditor.exit();
  }

  @action
  undo() {
    this.visualEditor.undo();
  }

  @action
  redo() {
    this.visualEditor.redo();
  }

  @action
  reset() {
    this.visualEditor.resetAll();
  }

  /**
   * Whether the Save button should be enabled. Requires:
   *   1. The editor to know which theme to write to (`activeThemeId` set).
   *   2. There to be in-memory edits to save (`isDirty` true) — saving an
   *      empty draft would be a no-op.
   *   3. No save currently in flight.
   *
   * @returns {boolean}
   */
  get canSave() {
    return (
      !this.isSaving &&
      this.visualEditor.isDirty &&
      this.visualEditor.activeThemeId != null
    );
  }

  @action
  save() {
    if (!this.canSave) {
      return;
    }
    if (this.visualEditor.hasValidationWarnings) {
      // Warnings on the session-draft layer are by design (mid-edit
      // invalid states are tolerated, not blocked). The user might still
      // want to save and come back later — confirm before posting so they
      // don't ship a half-finished layout by accident.
      this.dialog.confirm({
        message: i18n("visual_editor.chrome.save_with_warnings_confirm", {
          count: this.visualEditor.validationWarnings.length,
        }),
        confirmButtonLabel: "visual_editor.chrome.save_anyway",
        didConfirm: () => this._performSave(),
      });
      return;
    }
    this._performSave();
  }

  async _performSave() {
    this.isSaving = true;
    this.saveErrorMessage = null;
    try {
      const result = await this.visualEditorPersistence.saveAll(
        this.visualEditor.activeThemeId
      );
      if (result.errors.length) {
        this.saveErrorMessage = result.errors
          .map((e) => `${e.outlet}: ${e.message}`)
          .join("; ");
      }
      // The save also collapses session-drafts into the theme layer, so
      // `isDirty` (driven by `_initialSnapshots`) needs to be reset for
      // the toolbar to reflect "no unsaved changes". Snapshots are tied
      // to draft-entry references that no longer exist after save.
      this.visualEditor._initialSnapshots.clear();
      this.visualEditor._undoStack.length = 0;
      this.visualEditor._redoStack.length = 0;
    } finally {
      this.isSaving = false;
    }
  }

  <template>
    {{#if this.visualEditor.isActive}}
      <div
        class={{this.shellClasses}}
        {{didInsert this.setupBodyClasses}}
        {{dDragAndDropAutoScroll target="window" types=VE_DRAG_TYPES}}
      >
        {{! Mounts a ProseMirror editor over whichever inline-edit region is
            active. Rendered as a no-DOM controller — its only visible output
            is the editor it portals into the renderer's span. }}
        <InlineEditController />
        <div class="visual-editor-toolbar">
          <div class="toolbar-left">
            {{dIcon "wand-magic-sparkles"}}
            <span class="toolbar-title">Visual Editor</span>
            <OutletJumpSelect />
          </div>
          <div class="toolbar-right">
            <SimulationControls />
            {{#if this.visualEditor.hasValidationWarnings}}
              <DButton
                class={{dConcatClass
                  "btn-flat visual-editor-btn-warnings"
                  (if this.warningsPanelOpen "--open")
                }}
                @icon="triangle-exclamation"
                @translatedLabel={{this.visualEditor.validationWarnings.length}}
                @title="visual_editor.chrome.warnings_button_title"
                @action={{this.toggleWarningsPanel}}
              />
            {{/if}}
            <DButton
              class="visual-editor-btn-undo"
              @icon="arrow-rotate-left"
              @title="visual_editor.chrome.undo"
              @disabled={{if this.visualEditor.canUndo false true}}
              @action={{this.undo}}
            />
            <DButton
              class="visual-editor-btn-redo"
              @icon="arrow-rotate-right"
              @title="visual_editor.chrome.redo"
              @disabled={{if this.visualEditor.canRedo false true}}
              @action={{this.redo}}
            />
            <DButton
              class="visual-editor-btn-reset"
              @label="visual_editor.chrome.reset"
              @disabled={{if this.visualEditor.isDirty false true}}
              @action={{this.reset}}
            />
            <DButton
              class="btn-primary visual-editor-btn-save"
              @label="visual_editor.chrome.save"
              @disabled={{if this.canSave false true}}
              @action={{this.save}}
            />
            <DButton
              @icon="xmark"
              @label="visual_editor.chrome.exit"
              @action={{this.exit}}
            />
          </div>
        </div>

        {{#if this.saveErrorMessage}}
          <div class="visual-editor-save-error" role="alert">
            <span class="visual-editor-save-error__icon">
              {{dIcon "triangle-exclamation"}}
            </span>
            <span class="visual-editor-save-error__message">
              {{this.saveErrorMessage}}
            </span>
            <DButton
              class="btn-flat visual-editor-save-error__dismiss"
              @icon="xmark"
              @ariaLabel="visual_editor.chrome.dismiss_error"
              @action={{this.dismissSaveError}}
            />
          </div>
        {{/if}}

        {{#if this.warningsPanelOpen}}
          <div class="visual-editor-warnings-panel" role="region">
            <div class="visual-editor-warnings-panel__header">
              {{dIcon "triangle-exclamation"}}
              <span>{{i18n
                  "visual_editor.chrome.warnings_panel_title"
                  count=this.visualEditor.validationWarnings.length
                }}</span>
            </div>
            <ul class="visual-editor-warnings-panel__list">
              {{#each this.visualEditor.validationWarnings as |w|}}
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
            "visual-editor-panel"
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
                @label="visual_editor.chrome.tab_palette"
                @action={{fn this.setLeftPanelTab "palette"}}
              />
              <DButton
                class={{dConcatClass
                  "btn-flat panel-tab"
                  (if (this.isLeftPanelTabActive "outline") "--active")
                }}
                @label="visual_editor.chrome.tab_outline"
                @action={{fn this.setLeftPanelTab "outline"}}
              />
            {{/unless}}
            <DButton
              class="btn-flat panel-collapse-toggle"
              @icon={{if this.leftCollapsed "chevron-right" "chevron-left"}}
              @title={{if
                this.leftCollapsed
                "visual_editor.chrome.expand_panel"
                "visual_editor.chrome.collapse_panel"
              }}
              @ariaLabel={{if
                this.leftCollapsed
                "visual_editor.chrome.expand_panel"
                "visual_editor.chrome.collapse_panel"
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

        <div class="visual-editor-canvas">
          <BlockBreadcrumb />
        </div>

        <div
          class={{dConcatClass
            "visual-editor-panel"
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
                "visual_editor.chrome.expand_panel"
                "visual_editor.chrome.collapse_panel"
              }}
              @ariaLabel={{if
                this.rightCollapsed
                "visual_editor.chrome.expand_panel"
                "visual_editor.chrome.collapse_panel"
              }}
              @action={{this.toggleRightCollapsed}}
            />
            {{#unless this.rightCollapsed}}
              <span>{{i18n "visual_editor.chrome.panel_inspector"}}</span>
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
function readBoolStorage(key) {
  try {
    return localStorage.getItem(key) === "true";
  } catch {
    return false;
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
