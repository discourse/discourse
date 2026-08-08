import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import type { ArgSchema } from "discourse/blocks/types";
import { eq } from "discourse/truth-helpers";
import type {
  ConditionLeaf,
  ConditionTypeMeta,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

type ConditionArgRow = {
  /** Argument name in the condition schema. */
  name: string;
  /** Core schema describing the argument. */
  schema: ArgSchema;
  /** Current authored argument value, bound directly to native inputs. */
  value: string | number | boolean | null | undefined;
  /** Current value formatted for the comma-separated array input. */
  displayValue: string | number | undefined;
  /** Whether the schema provides enumerated choices. */
  hasEnum: boolean;
  /** Enumerated choices offered by the schema. */
  enumValues: string[];
};

interface ConditionLeafArgsSignature {
  /** Condition metadata, value, and update callback. */
  Args: {
    /** Condition leaf whose arguments are being edited. */
    node?: ConditionLeaf;
    /** Registry descriptor for the condition type. */
    typeMeta: ConditionTypeMeta;
    /** Updates one argument on the condition leaf. */
    onChange: (
      /** Argument name to update. */
      name: string,
      /** Replacement argument value. */
      value: unknown
    ) => void;
  };
}

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
export default class ConditionLeafArgs extends Component<ConditionLeafArgsSignature> {
  /**
   * Flattens `argsSchema` into a list of `{name, schema, value}`
   * descriptors so the template can iterate uniformly.
   */
  get argRows(): ConditionArgRow[] {
    const schema = this.args.typeMeta?.argsSchema ?? {};
    return Object.entries(schema).map(([name, argSchema]) => {
      const value = this.args.node?.[name];
      return {
        name,
        schema: argSchema,
        // TODO(devxp-typescript-pending): authored argument values are `unknown`;
        // native inputs render the raw value, so surface it as an attribute value.
        value: value as string | number | boolean | null | undefined,
        displayValue: (Array.isArray(value) ? value.join(", ") : value) as
          | string
          | number
          | undefined,
        hasEnum: Array.isArray(argSchema.enum) && argSchema.enum.length > 0,
        // TODO(devxp-typescript-pending): enum entries are authored as `unknown`;
        // keep the raw values so non-string options still match on comparison.
        enumValues: (argSchema.enum ?? []) as string[],
      };
    });
  }

  /**
   * Updates a string argument.
   *
   * @param name - Argument name to update.
   * @param event - Text-input event.
   */
  @action
  handleStringInput(name: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    this.args.onChange(name, event.currentTarget.value);
  }

  /**
   * Updates a numeric argument when its input is valid.
   *
   * @param name - Argument name to update.
   * @param event - Number-input event.
   */
  @action
  handleNumberInput(name: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    if (raw === "") {
      this.args.onChange(name, undefined);
      return;
    }
    const parsed = Number(raw);
    if (Number.isFinite(parsed)) {
      this.args.onChange(name, parsed);
    }
  }

  /**
   * Updates a boolean argument.
   *
   * @param name - Argument name to update.
   * @param event - Boolean-select event.
   */
  @action
  handleBooleanInput(name: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLSelectElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    if (raw === "") {
      this.args.onChange(name, undefined);
      return;
    }
    this.args.onChange(name, raw === "true");
  }

  /**
   * Updates an enumerated argument.
   *
   * @param name - Argument name to update.
   * @param event - Enum-select event.
   */
  @action
  handleEnumInput(name: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLSelectElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    this.args.onChange(name, raw === "" ? undefined : raw);
  }

  /**
   * Updates an array argument from comma-delimited input.
   *
   * @param name - Argument name to update.
   * @param event - Array-input event.
   */
  @action
  handleArrayInput(name: string, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const raw = event.currentTarget.value.trim();
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
              {{#each row.enumValues as |enumValue|}}
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
