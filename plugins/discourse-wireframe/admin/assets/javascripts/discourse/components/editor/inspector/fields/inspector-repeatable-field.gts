import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type { ArgSchema } from "discourse/blocks/types";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import {
  type InspectorField,
  schemaToFields,
} from "discourse/plugins/discourse-wireframe/discourse/lib/layout/schema-to-fields";
import type WireframeLayoutQueryService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-query";
import type WireframeLayoutSignalService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-layout-signal";
import type WireframeMutationEngineService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-mutation-engine";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

type RepeatableFieldData = {
  /** FormKit field name. */
  name: string;
};

// TODO(devxp-typescript-pending): replace `RepeatableFieldData` once FormKit
// exports the type of the field data yielded by a custom control.

type RepeatableItem = Record<string, unknown>;

// Erased pass-through cast. The `commit*` actions store each field value as a
// primitive, but `get` yields `unknown`, which is not assignable to an
// attribute value. This returns the value unchanged, so the input renders the
// raw stored value exactly as the untyped original did — no runtime narrowing.
function fieldAttrValue(
  value: unknown
): string | number | boolean | null | undefined {
  return value as string | number | boolean | null | undefined;
}

interface InspectorRepeatableFieldSignature {
  /** Repeatable field data and item schema. */
  Args: {
    /** FormKit field data identifying the block argument. */
    custom: RepeatableFieldData;
    /** Canonical array argument schema. */
    schema: ArgSchema;
  };
}

/**
 * Custom FormKit control for an array of structured items
 * (`type: "array", itemType: "object", itemSchema: {...}`).
 *
 * Like the image control, it bypasses FormKit's draft: it reads the live array
 * from `entry.args` and writes the whole array back via
 * `wireframeMutationEngine.setArg` (an immediate write, so add-then-remove reads a fresh value
 * rather than a stale pre-flush one). The inspector and canvas stay in sync.
 *
 * Each item is one row; each row's fields are derived from the arg's
 * `itemSchema` via the same `schemaToFields` mapper the rest of the inspector
 * uses, so a sub-field's declared control drives how it's edited. Rows can be
 * added, removed, and reordered, and a whole array can be pasted in as JSON.
 */
export default class InspectorRepeatableField extends Component<InspectorRepeatableFieldSignature> {
  /** Commits immediate block-argument changes. */
  @service declare wireframeMutationEngine: WireframeMutationEngineService;

  /** Resolves the selected entry's live arguments. */
  @service declare wireframeLayoutQuery: WireframeLayoutQueryService;

  /** Invalidates reads after layout mutations. */
  @service declare wireframeLayoutSignal: WireframeLayoutSignalService;

  /** Provides the selected block key. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Draft text for the JSON import box; committed on demand. */
  @tracked importDraft: string = "";

  /** Current JSON import validation error. */
  @tracked importError: string | null = null;

  /** Selected block key, or `null` when nothing is selected. */
  get blockKey(): string | null {
    return this.wireframeSelection.selectedBlockKey;
  }

  /** Argument name carried by FormKit's field wrapper. */
  get argName(): string {
    return this.args.custom.name;
  }

  /** Per-item argument schema. */
  get itemSchema(): Record<string, ArgSchema> {
    return this.args.schema?.itemSchema ?? {};
  }

  /**
   * Inspector-field descriptors for each item sub-field, reusing the shared
   * schema→fields mapper so a sub-field's `ui.control` resolves the same way it
   * would at the top level.
   *
   * @returns Inspector descriptors for each item field.
   */
  get itemFields(): InspectorField[] {
    return schemaToFields(this.itemSchema);
  }

  /**
   * Live array value off `entry.args`. Reading through the trackedObject (and
   * touching `wireframeLayoutSignal.version`) re-renders this control on any mutation.
   *
   * @returns Structured items stored in the selected argument.
   */
  get items(): unknown[] {
    void this.wireframeLayoutSignal.version;
    const key = this.blockKey;
    if (!key) {
      return [];
    }
    const entry = this.wireframeLayoutQuery.findEntryAndOutletSync(key)?.entry;
    const value = entry?.args?.[this.argName];
    return Array.isArray(value) ? value : [];
  }

  /** Adds a default-shaped item. */
  @action
  addItem(): void {
    this.#writeItems([...this.items, this.#buildDefaultItem()]);
  }

  /**
   * Removes one item.
   *
   * @param index - Item index to remove.
   */
  @action
  removeItem(index: number): void {
    this.#writeItems(this.items.filter((_, i) => i !== index));
  }

  /**
   * Moves an item up (`delta = -1`) or down (`delta = +1`), clamped to bounds.
   *
   * @param index - Item index to move.
   * @param delta - Signed destination offset.
   */
  @action
  moveItem(index: number, delta: number): void {
    const target = index + delta;
    const items = this.items;
    if (target < 0 || target >= items.length) {
      return;
    }
    const next = [...items];
    [next[index], next[target]] = [next[target], next[index]];
    this.#writeItems(next);
  }

  /**
   * Commits a text item field.
   *
   * @param index - Item index to update.
   * @param fieldName - Item field name.
   * @param event - Text-input event.
   */
  @action
  commitText(index: number, fieldName: string, event: Event): void {
    if (
      !(
        event.currentTarget instanceof HTMLInputElement ||
        event.currentTarget instanceof HTMLSelectElement
      )
    ) {
      return;
    }
    this.#setField(index, fieldName, event.currentTarget.value);
  }

  /**
   * Commits a numeric item field.
   *
   * @param index - Item index to update.
   * @param fieldName - Item field name.
   * @param event - Number-input event.
   */
  @action
  commitNumber(index: number, fieldName: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const parsed = parseFloat(event.currentTarget.value);
    this.#setField(index, fieldName, Number.isNaN(parsed) ? 0 : parsed);
  }

  /**
   * Commits a boolean item field.
   *
   * @param index - Item index to update.
   * @param fieldName - Item field name.
   * @param event - Checkbox event.
   */
  @action
  commitToggle(index: number, fieldName: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.#setField(index, fieldName, event.currentTarget.checked);
  }

  /**
   * Updates the JSON import draft.
   *
   * @param event - Import-textarea event.
   */
  @action
  updateImportDraft(event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    this.importDraft = event.currentTarget.value;
    this.importError = null;
  }

  /**
   * Replaces the whole array from the JSON in the import box. Accepts only a
   * JSON array; anything else surfaces a soft error and leaves the items
   * untouched.
   */
  @action
  importJson(): void {
    let parsed: unknown;
    try {
      parsed = JSON.parse(this.importDraft);
    } catch {
      this.importError = i18n("wireframe.inspector.repeatable.import_invalid");
      return;
    }
    if (!Array.isArray(parsed)) {
      this.importError = i18n("wireframe.inspector.repeatable.import_invalid");
      return;
    }
    this.importError = null;
    this.importDraft = "";
    this.#writeItems(parsed);
  }

  /**
   * Writes the whole array back to the selected block's arg, immediately.
   *
   * @param next - Replacement structured items.
   */
  #writeItems(next: unknown[]): void {
    if (!this.blockKey) {
      return;
    }
    this.wireframeMutationEngine.setArg(this.blockKey, this.argName, next);
  }

  /**
   * Builds a fresh item seeded from each sub-field's default (or a type-based
   * empty value), so a new row is valid-shaped from the start.
   *
   * @returns A default-shaped structured item.
   */
  #buildDefaultItem(): RepeatableItem {
    const item: RepeatableItem = {};
    for (const field of this.itemFields) {
      if (field.default !== undefined) {
        item[field.name] = field.default;
      } else if (field.schema?.type === "boolean") {
        item[field.name] = false;
      } else if (field.schema?.type === "number") {
        item[field.name] = 0;
      } else {
        item[field.name] = "";
      }
    }
    return item;
  }

  /**
   * Sets one sub-field on the item at `index` to `value` and writes the array.
   *
   * @param index - Item index to update.
   * @param fieldName - Item field name.
   * @param value - Replacement field value.
   */
  #setField(index: number, fieldName: string, value: unknown): void {
    const next = this.items.map((item, i) =>
      i === index ? { ...itemProperties(item), [fieldName]: value } : item
    );
    this.#writeItems(next);
  }

  <template>
    <div class="wireframe-repeatable">
      {{#each this.items key="@index" as |item index|}}
        <div class="wireframe-repeatable__row">
          <div class="wireframe-repeatable__fields">
            {{#each this.itemFields as |field|}}
              <label class="wireframe-repeatable__field">
                <span class="wireframe-repeatable__field-label">
                  {{field.title}}
                </span>
                {{#if (eq field.control "toggle")}}
                  <input
                    type="checkbox"
                    checked={{fieldAttrValue (get item field.name)}}
                    {{on "change" (fn this.commitToggle index field.name)}}
                  />
                {{else if (eq field.control "number")}}
                  <input
                    type="number"
                    value={{fieldAttrValue (get item field.name)}}
                    {{on "change" (fn this.commitNumber index field.name)}}
                  />
                {{else if (eq field.control "select")}}
                  <select {{on "change" (fn this.commitText index field.name)}}>
                    {{#each field.options as |opt|}}
                      <option
                        value={{opt}}
                        selected={{eq opt (get item field.name)}}
                      >
                        {{opt}}
                      </option>
                    {{/each}}
                  </select>
                {{else}}
                  <input
                    type="text"
                    value={{fieldAttrValue (get item field.name)}}
                    placeholder={{field.placeholder}}
                    {{on "blur" (fn this.commitText index field.name)}}
                  />
                {{/if}}
              </label>
            {{/each}}
          </div>

          <div class="wireframe-repeatable__row-actions">
            <button
              type="button"
              class="btn btn-flat wireframe-repeatable__move-up"
              title={{i18n "wireframe.inspector.repeatable.move_up"}}
              {{on "click" (fn this.moveItem index -1)}}
            >
              {{dIcon "arrow-up"}}
            </button>
            <button
              type="button"
              class="btn btn-flat wireframe-repeatable__move-down"
              title={{i18n "wireframe.inspector.repeatable.move_down"}}
              {{on "click" (fn this.moveItem index 1)}}
            >
              {{dIcon "arrow-down"}}
            </button>
            <button
              type="button"
              class="btn btn-flat wireframe-repeatable__remove"
              title={{i18n "wireframe.inspector.repeatable.remove_item"}}
              {{on "click" (fn this.removeItem index)}}
            >
              {{dIcon "trash-can"}}
            </button>
          </div>
        </div>
      {{/each}}

      <button
        type="button"
        class="btn btn-default wireframe-repeatable__add"
        {{on "click" this.addItem}}
      >
        {{dIcon "plus"}}
        {{i18n "wireframe.inspector.repeatable.add_item"}}
      </button>

      <details class="wireframe-repeatable__import">
        <summary>{{i18n
            "wireframe.inspector.repeatable.import_label"
          }}</summary>
        <textarea
          class="wireframe-repeatable__import-input"
          value={{this.importDraft}}
          placeholder={{i18n
            "wireframe.inspector.repeatable.import_placeholder"
          }}
          {{on "input" this.updateImportDraft}}
        ></textarea>
        {{#if this.importError}}
          <p class="wireframe-repeatable__import-error">{{this.importError}}</p>
        {{/if}}
        <button
          type="button"
          class="btn btn-default wireframe-repeatable__import-apply"
          {{on "click" this.importJson}}
        >
          {{i18n "wireframe.inspector.repeatable.import_apply"}}
        </button>
      </details>
    </div>
  </template>
}

/**
 * Returns the enumerable properties used when updating an item.
 *
 * @param item - Runtime repeatable item.
 * @returns Item properties, or an empty object for a primitive item.
 */
function itemProperties(item: unknown): object {
  return typeof item === "object" && item !== null ? item : {};
}
