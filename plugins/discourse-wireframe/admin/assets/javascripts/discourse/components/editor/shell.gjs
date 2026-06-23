// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import DComboButton from "discourse/ui-kit/d-combo-button";
import DDropdownMenu from "discourse/ui-kit/d-dropdown-menu";
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
  @service wireframe;

  /**
   * In-flight Save state. Toggling this true grays out the Save button so a
   * user can't double-tap it while we're awaiting the server. Failures are
   * surfaced as a banner row beneath the toolbar (see `saveErrorMessage`).
   */
  @tracked isSaving = false;
  @tracked saveErrorMessage = null;
  @tracked justSavedDraft = false;
  @tracked warningsPanelOpen = false;
  @tracked leftPanelTab = "palette";
  @tracked leftCollapsed = readBoolStorage("ve.leftCollapsed");
  @tracked rightCollapsed = readBoolStorage("ve.rightCollapsed");
  @tracked dimNonEditable = readBoolStorage("ve.dimNonEditable", true);

  isLeftPanelTabActive = (tab) => this.leftPanelTab === tab;

  /** The Publish dropdown menu's API handle, captured so the menu closes before publishing. */
  #publishMenu = null;

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

  /**
   * Whether the toolbar's Save draft / Publish control should be enabled (both
   * actions share one gate). Requires:
   *   1. The editor to know which theme to write to (`activeThemeId` set).
   *   2. There to be in-memory edits (`isDirty` true) — saving or publishing
   *      with nothing edited would be a no-op.
   *   3. No save or publish currently in flight.
   *
   * @returns {boolean}
   */
  get canSubmit() {
    return (
      !this.isSaving &&
      this.wireframe.isDirty &&
      this.wireframe.activeThemeId != null
    );
  }

  /**
   * Whether Save draft is available: submittable AND there are edits not yet
   * drafted, so it disables once the current edits are saved and re-enables on
   * the next change. Publish stays available via `canSubmit` regardless.
   *
   * @returns {boolean}
   */
  get canSaveDraft() {
    return this.canSubmit && this.wireframe.hasUnsavedDraftEdits;
  }

  /**
   * Whether the toolbar's Publish is available. Direct publish isn't supported
   * for a core system theme (Foundation, Horizon) — those route through a
   * per-outlet companion component in the inspector instead — so Publish is
   * disabled while Save draft stays available.
   *
   * @returns {boolean}
   */
  get canPublish() {
    return this.canSubmit && !this.wireframe.activeThemeIsSystem;
  }

  /**
   * Whether the primary button shows its transient "Saved" confirmation: a save
   * just succeeded and no new edit has re-enabled Save draft yet. Drives the
   * label/icon swap and the fade animation.
   *
   * @returns {boolean}
   */
  get saveDraftJustConfirmed() {
    return this.justSavedDraft && !this.canSaveDraft;
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
  dismissSaveError() {
    this.saveErrorMessage = null;
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

  @action
  discardAll() {
    this.wireframe.discardAll();
  }

  @action
  saveDrafts() {
    if (!this.canSaveDraft) {
      return;
    }
    // No validation-warnings prompt here: a draft is private and never live, so
    // saving a mid-edit, still-invalid layout is exactly what drafts are for.
    this.#performSaveDrafts();
  }

  @action
  clearJustSavedDraft(event) {
    // The confirmation fade finished — revert the primary back to Save draft.
    if (event.animationName === "wireframe-draft-saved") {
      this.justSavedDraft = false;
    }
  }

  @action
  async publish() {
    await this.#publishMenu?.close();
    if (!this.canSubmit) {
      return;
    }
    if (this.wireframe.hasValidationWarnings) {
      // Warnings on the session-draft layer are by design (mid-edit
      // invalid states are tolerated, not blocked). Publishing goes live, so
      // confirm first — the user shouldn't ship a half-finished layout by
      // accident. (Save draft skips this; an invalid draft is fine.)
      this.dialog.confirm({
        message: i18n("wireframe.chrome.publish_with_warnings_confirm", {
          count: this.wireframe.validationWarnings.length,
        }),
        confirmButtonLabel: "wireframe.chrome.publish_anyway",
        didConfirm: () => this.#performPublish(),
      });
      return;
    }
    this.#performPublish();
  }

  @action
  registerPublishMenu(api) {
    this.#publishMenu = api;
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

  async #performSaveDrafts() {
    this.isSaving = true;
    this.saveErrorMessage = null;
    try {
      // The editor service drafts every edited outlet privately (no live write,
      // no broadcast); the outlets stay edited. Returns a banner message for any
      // outlet that couldn't be drafted, or null on success.
      this.saveErrorMessage = await this.wireframe.saveAllEditedDrafts();
      // Show the transient confirmation only when nothing failed.
      this.justSavedDraft = this.saveErrorMessage == null;
    } finally {
      this.isSaving = false;
    }
  }

  async #performPublish() {
    this.isSaving = true;
    this.saveErrorMessage = null;
    try {
      // The editor service owns the publish orchestration (per-outlet owner
      // targeting, the conflict prompt, edit-state reconciliation) so the
      // toolbar Publish and the per-outlet Publish share one path. It returns a
      // banner message for non-conflict errors, or null on success.
      this.saveErrorMessage = await this.wireframe.publishEditedOutlets();
    } finally {
      this.isSaving = false;
    }
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
            <DButton
              class="wireframe-btn-reset"
              @label="wireframe.chrome.discard_all"
              @disabled={{if this.wireframe.isDirty false true}}
              @action={{this.discardAll}}
            />
            <DComboButton class="wireframe-btn-save" as |combo|>
              <combo.Button
                class={{dConcatClass
                  "btn-primary wireframe-btn-save-draft"
                  (if this.saveDraftJustConfirmed "--just-saved")
                }}
                @icon={{if this.saveDraftJustConfirmed "check"}}
                @translatedLabel={{if
                  this.saveDraftJustConfirmed
                  (i18n "wireframe.chrome.draft_saved")
                  (i18n "wireframe.chrome.save_draft")
                }}
                @disabled={{unless this.canSaveDraft true}}
                @action={{this.saveDrafts}}
                {{on "animationend" this.clearJustSavedDraft}}
              />
              <combo.Menu
                class="btn-primary wireframe-btn-publish-menu"
                @identifier="wireframe-toolbar-publish"
                @title={{i18n "wireframe.chrome.publish"}}
                @ariaLabel={{i18n "wireframe.chrome.publish"}}
                @disabled={{unless this.canSubmit true}}
                @onRegisterApi={{this.registerPublishMenu}}
              >
                <DDropdownMenu as |dropdown|>
                  <dropdown.item>
                    <DButton
                      class="btn-flat wireframe-btn-publish"
                      @label="wireframe.chrome.publish"
                      @disabled={{unless this.canPublish true}}
                      @title={{if
                        this.wireframe.activeThemeIsSystem
                        (i18n "wireframe.chrome.publish_disabled_system")
                      }}
                      @action={{this.publish}}
                    />
                  </dropdown.item>
                </DDropdownMenu>
              </combo.Menu>
            </DComboButton>
            <DButton
              @icon="xmark"
              @label="wireframe.chrome.exit"
              @action={{this.exit}}
            />
          </div>
        </div>

        {{#if this.saveErrorMessage}}
          <div class="wireframe-save-error" role="alert">
            <span class="wireframe-save-error__icon">
              {{dIcon "triangle-exclamation"}}
            </span>
            <span class="wireframe-save-error__message">
              {{this.saveErrorMessage}}
            </span>
            <DButton
              class="btn-flat wireframe-save-error__dismiss"
              @icon="xmark"
              @ariaLabel="wireframe.chrome.dismiss_error"
              @action={{this.dismissSaveError}}
            />
          </div>
        {{/if}}

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
