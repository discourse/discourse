import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type SiteSettingsService from "discourse/services/site-settings";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import type { ConditionLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

type SettingOperator =
  | "enabled"
  | "equals"
  | "contains"
  | "includes"
  | "containsAny";

type ScalarSettingOperator = "equals" | "contains";

type ListSettingOperator = "includes" | "containsAny";

type SettingConditionLeaf = ConditionLeaf & {
  /** Site-setting key to inspect. */
  name?: string;
  /** Whether the setting must be truthy or falsy. */
  enabled?: boolean;
  /** Value that the setting must equal. */
  equals?: unknown;
  /** Values that may equal the setting. */
  includes?: unknown[];
  /** Value that a list setting must contain. */
  contains?: string;
  /** Values of which a list setting must contain at least one. */
  containsAny?: string[];
};

// TODO(devxp-typescript-pending): replace this authoring shape with core's
// `SettingConditionArgs` once the setting condition exports that contract.

interface SettingConditionEditorSignature {
  /** Setting condition and update callback. */
  Args: {
    /** Setting condition leaf being edited. */
    leaf: SettingConditionLeaf;
    /** Replaces the edited condition leaf. */
    onChange: (
      /** Updated setting condition leaf. */
      leaf: SettingConditionLeaf
    ) => void;
  };
}

/**
 * Context-sensitive editor for the `setting` condition. The condition
 * has five mutually-exclusive operators (`enabled` / `equals` /
 * `includes` / `contains` / `containsAny`) plus the required `name`.
 *
 * The UI presents the name + operator as the first decision, and the
 * value editor adapts to the chosen operator:
 *
 *  - `enabled` → segmented Enabled / Disabled.
 *  - `equals` → text input.
 *  - `contains` → text input.
 *  - `includes` / `containsAny` → multi-line textarea (one value per
 *     line).
 *
 * Site-setting names are surfaced via a `<datalist>` so authors get
 * autocomplete as they type — no full custom picker, but discoverable.
 */
const OPERATORS: readonly SettingOperator[] = [
  "enabled",
  "equals",
  "contains",
  "includes",
  "containsAny",
];

export default class SettingConditionEditor extends Component<SettingConditionEditorSignature> {
  // TODO(devxp-typescript-pending): use the site-settings service's exported
  // runtime instance type once core distinguishes it from the factory shim.
  /** Available client-side site settings. */
  @service declare siteSettings: SiteSettingsService;

  /**
   * Sorted, deduplicated list of site-setting keys for the `<datalist>`
   * autocomplete. The service exposes hundreds of keys; we surface
   * them all and let the browser's native filter narrow them as the
   * author types.
   */
  get settingNames(): string[] {
    return Object.keys(this.siteSettings).sort();
  }

  /** Operator represented by the current leaf fields. */
  get currentOperator(): SettingOperator {
    for (const op of OPERATORS) {
      if (this.args.leaf?.[op] !== undefined) {
        return op;
      }
    }
    return "enabled";
  }

  /** Boolean value shown by the enabled operator. */
  get enabledValue(): boolean {
    return this.args.leaf?.enabled !== false;
  }

  /** Scalar equality value formatted for its text input. */
  get equalsValue(): string {
    const value = this.args.leaf.equals;
    return value == null ? "" : String(value);
  }

  /**
   * Stringifies the current value for textarea operators (`includes`,
   * `containsAny`) where the schema is an array of strings. One per
   * line is the friendliest input — newlines beat commas because
   * setting values can themselves contain commas.
   */
  get listValueText(): string {
    const op = this.currentOperator;
    const raw = this.args.leaf?.[op];
    if (Array.isArray(raw)) {
      return raw.join("\n");
    }
    return "";
  }

  /**
   * Patches the leaf with the partial provided. Setting an operator
   * clears the other operators first, since `exactlyOne` is the
   * schema constraint.
   *
   * @param patch - Condition fields to replace or remove.
   */
  patch(patch: Partial<SettingConditionLeaf>): void {
    const next = { ...this.args.leaf };
    for (const [k, v] of Object.entries(patch)) {
      if (v === undefined) {
        delete next[k];
      } else {
        next[k] = v;
      }
    }
    this.args.onChange(next);
  }

  /**
   * Updates the site-setting key.
   *
   * @param event - Setting-name input event.
   */
  @action
  setName(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const value = event.currentTarget.value;
    this.patch({ name: value || undefined });
  }

  /**
   * Selects an operator and clears the mutually exclusive alternatives.
   *
   * @param op - Operator selected by the author.
   */
  @action
  setOperator(op: SettingOperator): void {
    // Clear every other operator — the schema enforces exactly one.
    const cleared: Partial<SettingConditionLeaf> = {
      enabled: undefined,
      equals: undefined,
      contains: undefined,
      includes: undefined,
      containsAny: undefined,
    };
    // Seed with a sensible default for the picked operator.
    if (op === "enabled") {
      cleared.enabled = true;
    } else if (op === "includes" || op === "containsAny") {
      cleared[op] = [];
    } else {
      cleared[op] = "";
    }
    this.patch(cleared);
  }

  /**
   * Updates the expected boolean state.
   *
   * @param value - Whether the setting must be enabled.
   */
  @action
  setEnabled(value: boolean): void {
    this.patch({ enabled: value });
  }

  /**
   * Updates an operator backed by a scalar text value.
   *
   * @param op - Scalar operator being edited.
   * @param event - Value-input event.
   */
  @action
  setScalarValue(op: ScalarSettingOperator, event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    this.patch({ [op]: raw });
  }

  /**
   * Updates an operator backed by newline-delimited values.
   *
   * @param op - List operator being edited.
   * @param event - Value-textarea event.
   */
  @action
  setListValue(op: ListSettingOperator, event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    const lines = raw
      .split("\n")
      .map((line) => line.trim())
      .filter(Boolean);
    this.patch({ [op]: lines });
  }

  <template>
    <div class="wireframe-condition-editor wireframe-condition-editor--setting">
      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n "wireframe.inspector.conditions.setting_editor.name_legend"}}
        </span>
        <input
          type="text"
          list="wf-setting-names"
          value={{@leaf.name}}
          placeholder={{i18n
            "wireframe.inspector.conditions.setting_editor.name_placeholder"
          }}
          {{on "input" this.setName}}
        />
        <datalist id="wf-setting-names">
          {{#each this.settingNames as |name|}}
            <option value={{name}}></option>
          {{/each}}
        </datalist>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n
            "wireframe.inspector.conditions.setting_editor.operator_legend"
          }}
        </span>
        <div class="wireframe-condition-editor__segmented" role="radiogroup">
          {{#each OPERATORS as |op|}}
            <DButton
              class={{dConcatClass
                "wireframe-condition-editor__segment"
                (if (eq this.currentOperator op) "--active")
              }}
              @ariaPressed={{eq this.currentOperator op}}
              @label={{concat
                "wireframe.inspector.conditions.setting_editor.operator_"
                op
              }}
              @action={{fn this.setOperator op}}
            />
          {{/each}}
        </div>
      </div>

      {{#if (eq this.currentOperator "enabled")}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.setting_editor.value_legend"
            }}
          </span>
          <div class="wireframe-condition-editor__segmented" role="radiogroup">
            <DButton
              class={{dConcatClass
                "wireframe-condition-editor__segment"
                (if this.enabledValue "--active")
              }}
              @ariaPressed={{this.enabledValue}}
              @label="wireframe.inspector.conditions.setting_editor.value_enabled"
              @action={{fn this.setEnabled true}}
            />
            <DButton
              class={{dConcatClass
                "wireframe-condition-editor__segment"
                (if (eq this.enabledValue false) "--active")
              }}
              @ariaPressed={{eq this.enabledValue false}}
              @label="wireframe.inspector.conditions.setting_editor.value_disabled"
              @action={{fn this.setEnabled false}}
            />
          </div>
        </div>
      {{else if (eq this.currentOperator "equals")}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.setting_editor.value_legend"
            }}
          </span>
          <input
            type="text"
            value={{this.equalsValue}}
            {{on "input" (fn this.setScalarValue "equals")}}
          />
        </div>
      {{else if (eq this.currentOperator "contains")}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.setting_editor.value_legend"
            }}
          </span>
          <input
            type="text"
            value={{@leaf.contains}}
            {{on "input" (fn this.setScalarValue "contains")}}
          />
        </div>
      {{else}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.setting_editor.value_legend"
            }}
          </span>
          <textarea
            class="wireframe-condition-editor__textarea"
            rows="3"
            placeholder={{i18n
              "wireframe.inspector.conditions.setting_editor.value_list_placeholder"
            }}
            {{on "input" (fn this.setListValue this.currentOperator)}}
          >{{this.listValueText}}</textarea>
          <span class="wireframe-condition-editor__help">
            {{i18n
              "wireframe.inspector.conditions.setting_editor.value_list_help"
            }}
          </span>
        </div>
      {{/if}}
    </div>
  </template>
}
