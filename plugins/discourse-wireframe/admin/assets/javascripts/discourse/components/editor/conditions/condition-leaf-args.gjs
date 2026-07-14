// @ts-check
import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";

/**
 * Renders inputs for one leaf condition's args. Lightweight on purpose:
 * a per-arg input is rendered based on the arg's `type` (string /
 * number / boolean / array / enum) without pulling in FormKit.
 *
 * Args:
 *  - `@typeMeta` — the entry from `blocks.listConditionTypes()` for
 *     this leaf's type. Provides `argsSchema`.
 *  - `@node` — the leaf object (`{type, ...args}`). Used to read
 *     current values.
 *  - `@onChange(name, value)` — bubble an arg change up to the row /
 *     builder.
 */
export default class ConditionLeafArgs extends Component {
  /**
   * Flattens `argsSchema` into a list of `{name, schema, value}`
   * descriptors so the template can iterate uniformly.
   */
  get argRows() {
    const schema = this.args.typeMeta?.argsSchema ?? {};
    return Object.entries(schema).map(([name, argSchema]) => {
      const value = this.args.node?.[name];
      return {
        name,
        schema: argSchema,
        value,
        displayValue: Array.isArray(value) ? value.join(", ") : value,
        hasEnum: Array.isArray(argSchema.enum) && argSchema.enum.length > 0,
      };
    });
  }

  @action
  handleStringInput(name, event) {
    this.args.onChange(name, event.target.value);
  }

  @action
  handleNumberInput(name, event) {
    const raw = event.target.value;
    if (raw === "") {
      this.args.onChange(name, undefined);
      return;
    }
    const parsed = Number(raw);
    if (Number.isFinite(parsed)) {
      this.args.onChange(name, parsed);
    }
  }

  @action
  handleBooleanInput(name, event) {
    const raw = event.target.value;
    if (raw === "") {
      this.args.onChange(name, undefined);
      return;
    }
    this.args.onChange(name, raw === "true");
  }

  @action
  handleEnumInput(name, event) {
    const raw = event.target.value;
    this.args.onChange(name, raw === "" ? undefined : raw);
  }

  @action
  handleArrayInput(name, event) {
    const raw = event.target.value.trim();
    if (raw === "") {
      this.args.onChange(name, undefined);
      return;
    }
    this.args.onChange(
      name,
      raw
        .split(",")
        .map((item) => item.trim())
        .filter(Boolean)
    );
  }

  <template>
    <div class="wireframe-condition-leaf-args">
      {{#each this.argRows as |row|}}
        <label class="wireframe-condition-leaf-args__row">
          <span class="wireframe-condition-leaf-args__name">
            {{row.name}}
            {{#if row.schema.required}}<span aria-hidden="true">*</span>{{/if}}
          </span>

          {{#if row.hasEnum}}
            <select {{on "change" (fn this.handleEnumInput row.name)}}>
              <option value="" selected={{eq row.value undefined}}>—</option>
              {{#each row.schema.enum as |enumValue|}}
                <option value={{enumValue}} selected={{eq row.value enumValue}}>
                  {{enumValue}}
                </option>
              {{/each}}
            </select>
          {{else if (eq row.schema.type "boolean")}}
            <select {{on "change" (fn this.handleBooleanInput row.name)}}>
              <option value="" selected={{eq row.value undefined}}>—</option>
              <option value="true" selected={{eq row.value true}}>
                true
              </option>
              <option value="false" selected={{eq row.value false}}>
                false
              </option>
            </select>
          {{else if (eq row.schema.type "number")}}
            <input
              type="number"
              value={{row.value}}
              min={{row.schema.min}}
              max={{row.schema.max}}
              {{on "input" (fn this.handleNumberInput row.name)}}
            />
          {{else if (eq row.schema.type "array")}}
            <input
              type="text"
              value={{row.displayValue}}
              placeholder="comma, separated, values"
              {{on "input" (fn this.handleArrayInput row.name)}}
            />
          {{else}}
            <input
              type="text"
              value={{row.value}}
              {{on "input" (fn this.handleStringInput row.name)}}
            />
          {{/if}}
        </label>
      {{else}}
        <p class="wireframe-condition-leaf-args__no-args">
          This condition takes no arguments.
        </p>
      {{/each}}
    </div>
  </template>
}
