// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, get } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { schemaToFields } from "../../lib/schema-to-fields";

/**
 * Custom FormKit control for an array of structured items
 * (`type: "array", itemType: "object", itemSchema: {...}`).
 *
 * Like the image control, it bypasses FormKit's draft: it reads the live array
 * from `entry.args` via the wireframe service and writes the whole array back
 * with `setArg` (an immediate write, so add-then-remove reads a fresh value
 * rather than a stale pre-flush one). The inspector and canvas stay in sync.
 *
 * Each item is one row; each row's fields are derived from the arg's
 * `itemSchema` via the same `schemaToFields` mapper the rest of the inspector
 * uses, so a sub-field's declared control drives how it's edited. Rows can be
 * added, removed, and reordered, and a whole array can be pasted in as JSON.
 */
export default class InspectorRepeatableField extends Component {
  @service wireframe;

  /** Draft text for the JSON import box; committed on demand. */
  @tracked importDraft = "";
  @tracked importError = null;

  /** @returns {string|null} */
  get blockKey() {
    return this.wireframe.selectedBlockKey;
  }

  /** @returns {string} The arg name, carried on FormKit's field wrapper. */
  get argName() {
    return this.args.custom?.name;
  }

  /** @returns {Object} The per-item field schema. */
  get itemSchema() {
    return this.args.schema?.itemSchema ?? {};
  }

  /**
   * Inspector-field descriptors for each item sub-field, reusing the shared
   * schema→fields mapper so a sub-field's `ui.control` resolves the same way it
   * would at the top level.
   *
   * @returns {Array<Object>}
   */
  get itemFields() {
    return schemaToFields(this.itemSchema);
  }

  /**
   * Live array value off `entry.args`. Reading through the trackedObject (and
   * touching `structuralVersion`) re-renders this control on any mutation.
   *
   * @returns {Array<Object>}
   */
  get items() {
    // eslint-disable-next-line no-unused-vars
    const _v = this.wireframe.structuralVersion;
    const key = this.blockKey;
    if (!key) {
      return [];
    }
    const entry = this.wireframe.layoutQuery.findEntryAndOutletSync(key)?.entry;
    const value = entry?.args?.[this.argName];
    return Array.isArray(value) ? value : [];
  }

  @action
  addItem() {
    this.#writeItems([...this.items, this.#buildDefaultItem()]);
  }

  @action
  removeItem(index) {
    this.#writeItems(this.items.filter((_, i) => i !== index));
  }

  /**
   * Moves an item up (`delta = -1`) or down (`delta = +1`), clamped to bounds.
   *
   * @param {number} index
   * @param {number} delta
   */
  @action
  moveItem(index, delta) {
    const target = index + delta;
    const items = this.items;
    if (target < 0 || target >= items.length) {
      return;
    }
    const next = [...items];
    [next[index], next[target]] = [next[target], next[index]];
    this.#writeItems(next);
  }

  @action
  commitText(index, fieldName, event) {
    this.#setField(index, fieldName, event.target.value);
  }

  @action
  commitNumber(index, fieldName, event) {
    const parsed = parseFloat(event.target.value);
    this.#setField(index, fieldName, Number.isNaN(parsed) ? 0 : parsed);
  }

  @action
  commitToggle(index, fieldName, event) {
    this.#setField(index, fieldName, event.target.checked);
  }

  @action
  updateImportDraft(event) {
    this.importDraft = event.target.value;
    this.importError = null;
  }

  /**
   * Replaces the whole array from the JSON in the import box. Accepts only a
   * JSON array; anything else surfaces a soft error and leaves the items
   * untouched.
   */
  @action
  importJson() {
    let parsed;
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
   * @param {Array<Object>} next
   */
  #writeItems(next) {
    if (!this.blockKey) {
      return;
    }
    this.wireframe.setArg(this.blockKey, this.argName, next);
  }

  /**
   * Builds a fresh item seeded from each sub-field's default (or a type-based
   * empty value), so a new row is valid-shaped from the start.
   *
   * @returns {Object}
   */
  #buildDefaultItem() {
    const item = {};
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
   * @param {number} index
   * @param {string} fieldName
   * @param {*} value
   */
  #setField(index, fieldName, value) {
    const next = this.items.map((item, i) =>
      i === index ? { ...item, [fieldName]: value } : item
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
                    checked={{get item field.name}}
                    {{on "change" (fn this.commitToggle index field.name)}}
                  />
                {{else if (eq field.control "number")}}
                  <input
                    type="number"
                    value={{get item field.name}}
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
                    value={{get item field.name}}
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
