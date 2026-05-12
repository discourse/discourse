// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import InspectorPanel from "./inspector-panel";
import OutletJumpSelect from "./outlet-jump-select";
import OutletsPanel from "./outlets-panel";
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

  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  @action
  setLeftPanelTab(tab) {
    this.leftPanelTab = tab;
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
      <div class="visual-editor-shell">
        <div class="visual-editor-toolbar">
          <div class="toolbar-left">
            {{dIcon "wand-magic-sparkles"}}
            <span class="toolbar-title">Visual Editor</span>
            <OutletJumpSelect />
          </div>
          <div class="toolbar-right">
            <SimulationControls />
            {{#if this.visualEditor.hasValidationWarnings}}
              <button
                type="button"
                class={{dConcatClass
                  "btn btn-flat visual-editor-btn-warnings"
                  (if this.warningsPanelOpen "--open")
                }}
                title={{i18n "visual_editor.chrome.warnings_button_title"}}
                {{on "click" this.toggleWarningsPanel}}
              >
                {{dIcon "triangle-exclamation"}}
                <span>{{this.visualEditor.validationWarnings.length}}</span>
              </button>
            {{/if}}
            <button
              type="button"
              class="btn btn-default visual-editor-btn-undo"
              title={{i18n "visual_editor.chrome.undo"}}
              disabled={{if this.visualEditor.canUndo false true}}
              {{on "click" this.undo}}
            >
              {{dIcon "arrow-rotate-left"}}
            </button>
            <button
              type="button"
              class="btn btn-default visual-editor-btn-redo"
              title={{i18n "visual_editor.chrome.redo"}}
              disabled={{if this.visualEditor.canRedo false true}}
              {{on "click" this.redo}}
            >
              {{dIcon "arrow-rotate-right"}}
            </button>
            <button
              type="button"
              class="btn btn-default visual-editor-btn-reset"
              disabled={{if this.visualEditor.isDirty false true}}
              {{on "click" this.reset}}
            >
              <span>{{i18n "visual_editor.chrome.reset"}}</span>
            </button>
            <button
              type="button"
              class="btn btn-primary visual-editor-btn-save"
              disabled={{if this.canSave false true}}
              {{on "click" this.save}}
            >
              <span>{{i18n "visual_editor.chrome.save"}}</span>
            </button>
            <button
              type="button"
              class="btn btn-default"
              {{on "click" this.exit}}
            >
              {{dIcon "xmark"}}
              <span>{{i18n "visual_editor.chrome.exit"}}</span>
            </button>
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
            <button
              type="button"
              class="btn btn-flat visual-editor-save-error__dismiss"
              aria-label={{i18n "visual_editor.chrome.dismiss_error"}}
              {{on "click" this.dismissSaveError}}
            >
              {{dIcon "xmark"}}
            </button>
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

        <div class="visual-editor-panel --left">
          <div class="panel-header panel-header--tabs">
            <button
              type="button"
              class={{dConcatClass
                "panel-tab"
                (if (this.isLeftPanelTabActive "palette") "--active")
              }}
              {{on "click" (fn this.setLeftPanelTab "palette")}}
            >
              {{i18n "visual_editor.chrome.tab_palette"}}
            </button>
            <button
              type="button"
              class={{dConcatClass
                "panel-tab"
                (if (this.isLeftPanelTabActive "outline") "--active")
              }}
              {{on "click" (fn this.setLeftPanelTab "outline")}}
            >
              {{i18n "visual_editor.chrome.tab_outline"}}
            </button>
            <button
              type="button"
              class={{dConcatClass
                "panel-tab"
                (if (this.isLeftPanelTabActive "outlets") "--active")
              }}
              {{on "click" (fn this.setLeftPanelTab "outlets")}}
            >
              {{i18n "visual_editor.chrome.tab_outlets"}}
            </button>
          </div>
          <div class="panel-body">
            {{#if (this.isLeftPanelTabActive "palette")}}
              <PalettePanel />
            {{else if (this.isLeftPanelTabActive "outline")}}
              <OutlinePanel />
            {{else}}
              <OutletsPanel />
            {{/if}}
          </div>
        </div>

        <div class="visual-editor-canvas"></div>

        <div class="visual-editor-panel --right">
          <div class="panel-header">{{i18n
              "visual_editor.chrome.panel_inspector"
            }}</div>
          <div class="panel-body">
            <InspectorPanel />
          </div>
        </div>
      </div>
    {{/if}}
  </template>
}
