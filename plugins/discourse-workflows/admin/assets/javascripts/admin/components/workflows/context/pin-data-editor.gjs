import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { popupAjaxError } from "discourse/lib/ajax-error";
import loadCodemirrorEditor from "discourse/lib/load-codemirror";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import buildJsonEditorExtensions from "../../../lib/workflows/json-editor-extensions";

const EMPTY_SEED = [{}];
const DEFAULT_MAX_BYTES = 1_048_576;

function prettyPrint(value) {
  try {
    return JSON.stringify(value, null, 2);
  } catch {
    return "";
  }
}

function byteLength(string) {
  if (typeof TextEncoder === "undefined") {
    return string.length * 4;
  }
  return new TextEncoder().encode(string).length;
}

// The storage shape on the backend is `[{ json: {...}, pairedItem? }]`.
// The UI hides that wrapper and shows the inner JSON payload directly.
function unwrapForDisplay(items) {
  if (!Array.isArray(items)) {
    return items;
  }
  return items.map((item) =>
    item && typeof item === "object" && "json" in item ? item.json : item
  );
}

// Lenient input normalization: accept either `[{...}]` (unwrapped, what the
// editor presents) or `[{"json": {...}}]` (wrapped, if the user pasted raw
// storage shape) and produce the canonical storage shape.
function wrapForStorage(payloads) {
  return payloads.map((payload) =>
    payload && typeof payload === "object" && "json" in payload
      ? payload
      : { json: payload }
  );
}

function validateUnwrappedShape(value) {
  if (!Array.isArray(value)) {
    return "invalid_shape_not_array";
  }
  if (value.length === 0) {
    return "invalid_shape_empty";
  }
  for (const payload of value) {
    if (
      payload === null ||
      typeof payload !== "object" ||
      Array.isArray(payload)
    ) {
      return "invalid_shape_item_not_object";
    }
    if ("json" in payload) {
      const inner = payload.json;
      if (inner === null || typeof inner !== "object" || Array.isArray(inner)) {
        return "invalid_shape_item_not_object";
      }
    }
  }
  return null;
}

export default class PinDataEditor extends Component {
  @service siteSettings;

  @tracked Editor;
  @tracked buffer;
  @tracked bufferBaseline;
  @tracked enteredFromEmpty = false;
  @tracked parseError = null;
  @tracked shapeError = null;
  @tracked isSaving = false;

  constructor() {
    super(...arguments);
    if (this.hasItems) {
      const initial = prettyPrint(unwrapForDisplay(this.args.initialItems));
      this.buffer = initial;
      this.bufferBaseline = initial;
    } else {
      this.buffer = "";
      this.bufferBaseline = "";
    }
    this.#recomputeValidity();
  }

  get hasItems() {
    return (
      Array.isArray(this.args.initialItems) && this.args.initialItems.length > 0
    );
  }

  // Show the editor when there's data to display or the user has explicitly
  // opted in from the empty state. Otherwise show the empty-state CTA.
  get showEditor() {
    return this.hasItems || this.enteredFromEmpty;
  }

  get maxBytes() {
    return (
      this.args.maxBytes ||
      this.siteSettings?.discourse_workflows_max_pin_data_bytes ||
      DEFAULT_MAX_BYTES
    );
  }

  get bufferBytes() {
    return byteLength(this.buffer);
  }

  get isOverSizeCap() {
    return this.bufferBytes > this.maxBytes;
  }

  get isNearSizeCap() {
    return !this.isOverSizeCap && this.bufferBytes > this.maxBytes * 0.9;
  }

  get sizeHint() {
    return i18n("discourse_workflows.pin_data.size_hint", {
      bytes: this.bufferBytes,
      max: this.maxBytes,
    });
  }

  get parsedPayloads() {
    if (this.parseError) {
      return null;
    }
    try {
      return JSON.parse(this.buffer);
    } catch {
      return null;
    }
  }

  get isDirty() {
    return this.buffer !== this.bufferBaseline;
  }

  get canSave() {
    return (
      this.isDirty &&
      !this.parseError &&
      !this.shapeError &&
      !this.isOverSizeCap &&
      !this.isSaving
    );
  }

  get saveDisabled() {
    return !this.canSave;
  }

  @action
  async loadEditor() {
    const Editor = await loadCodemirrorEditor();

    if (this.isDestroying || this.isDestroyed) {
      return;
    }
    this.Editor = Editor;
  }

  @action
  buildEditExtensions(cmParams) {
    return buildJsonEditorExtensions(cmParams, {
      onChange: (value) => this.updateBuffer(value),
    });
  }

  @action
  updateBuffer(value) {
    this.buffer = value;
    this.#recomputeValidity();
  }

  @action
  startFromEmpty() {
    const seed = prettyPrint(EMPTY_SEED);
    this.buffer = seed;
    // Baseline stays at "" so the seed counts as dirty and the Save button
    // is immediately visible. Cancel from this state returns to the empty CTA.
    this.bufferBaseline = "";
    this.enteredFromEmpty = true;
    this.#recomputeValidity();
  }

  @action
  cancel() {
    if (this.enteredFromEmpty && !this.hasItems) {
      this.enteredFromEmpty = false;
      this.buffer = "";
      this.bufferBaseline = "";
      this.parseError = null;
      this.shapeError = null;
      this.args.onCancel?.();
      return;
    }
    this.buffer = this.bufferBaseline;
    this.parseError = null;
    this.shapeError = null;
    this.args.onCancel?.();
  }

  @action
  async save() {
    if (!this.canSave) {
      return;
    }
    const payloads = this.parsedPayloads;
    if (!payloads) {
      return;
    }
    const items = wrapForStorage(payloads);

    this.isSaving = true;
    try {
      await this.args.session.pinNodeData(this.args.nodeName, items);
      // Update baseline so the Save/Cancel toolbar hides. The parent will
      // also re-render with the new pinned items flowing in via args.
      this.bufferBaseline = this.buffer;
      this.enteredFromEmpty = false;
      this.args.onSaved?.(items);
    } catch (error) {
      popupAjaxError(error);
    } finally {
      this.isSaving = false;
    }
  }

  #recomputeValidity() {
    if (this.buffer.trim() === "") {
      this.parseError = {
        message: i18n("discourse_workflows.pin_data.invalid_json_empty"),
      };
      this.shapeError = null;
      return;
    }

    let parsed;
    try {
      parsed = JSON.parse(this.buffer);
    } catch (error) {
      this.parseError = { message: error.message };
      this.shapeError = null;
      return;
    }

    this.parseError = null;
    const shapeKey = validateUnwrappedShape(parsed);
    this.shapeError = shapeKey
      ? { message: i18n(`discourse_workflows.pin_data.${shapeKey}`) }
      : null;
  }

  <template>
    {{#if this.showEditor}}
      <div
        class="workflows-context-panel__editor"
        {{didInsert this.loadEditor}}
      >
        {{#if this.isDirty}}
          <div class="workflows-context-panel__editor-toolbar">
            <button
              type="button"
              class="btn btn-primary btn-small workflows-context-panel__editor-save"
              disabled={{this.saveDisabled}}
              {{on "click" this.save}}
            >
              {{dIcon "check"}}
              {{i18n "discourse_workflows.pin_data.save"}}
            </button>
            <button
              type="button"
              class="btn btn-default btn-small workflows-context-panel__editor-cancel"
              {{on "click" this.cancel}}
            >
              {{i18n "discourse_workflows.pin_data.cancel"}}
            </button>
            <span
              class="workflows-context-panel__editor-size
                {{if
                  this.isOverSizeCap
                  'workflows-context-panel__editor-size--exceeded'
                }}
                {{if
                  this.isNearSizeCap
                  'workflows-context-panel__editor-size--near'
                }}"
            >
              {{this.sizeHint}}
            </span>
          </div>
        {{/if}}

        {{#if this.Editor}}
          <this.Editor
            @value={{this.buffer}}
            @extensions={{this.buildEditExtensions}}
            @class="workflows-context-panel__editor-codemirror"
            @lineWrapping={{true}}
          />
        {{else}}
          <div class="workflows-context-panel__editor-loading">
            {{i18n "discourse_workflows.pin_data.loading_editor"}}
          </div>
        {{/if}}

        {{#if this.isDirty}}
          {{#if this.parseError}}
            <div
              class="workflows-context-panel__editor-error alert alert-error"
            >
              {{dIcon "circle-exclamation"}}
              <span>{{i18n "discourse_workflows.pin_data.invalid_json"}}:
                {{this.parseError.message}}</span>
            </div>
          {{else if this.shapeError}}
            <div
              class="workflows-context-panel__editor-error alert alert-error"
            >
              {{dIcon "circle-exclamation"}}
              <span>{{this.shapeError.message}}</span>
            </div>
          {{/if}}

          {{#if this.isOverSizeCap}}
            <div
              class="workflows-context-panel__editor-error alert alert-error"
            >
              {{dIcon "circle-exclamation"}}
              <span>{{i18n "discourse_workflows.pin_data.size_exceeded"}}</span>
            </div>
          {{/if}}
        {{/if}}
      </div>
    {{else if @canEdit}}
      <div class="workflows-context-panel__empty-state">
        <h4 class="workflows-context-panel__empty-state-title">
          {{i18n "discourse_workflows.pin_data.empty_title"}}
        </h4>
        <button
          type="button"
          class="btn btn-primary workflows-context-panel__empty-state-btn"
          {{on "click" this.startFromEmpty}}
        >
          {{i18n "discourse_workflows.pin_data.add_sample_data"}}
        </button>
      </div>
    {{else}}
      <div class="workflows-context-panel__empty-state">
        <h4 class="workflows-context-panel__empty-state-title">
          {{i18n "discourse_workflows.pin_data.no_data_no_edit"}}
        </h4>
      </div>
    {{/if}}
  </template>
}
