// @ts-check
import Component from "@glimmer/component";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

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
const OPERATORS = ["enabled", "equals", "contains", "includes", "containsAny"];

export default class SettingConditionEditor extends Component {
  @service siteSettings;

  /**
   * Sorted, deduplicated list of site-setting keys for the `<datalist>`
   * autocomplete. The service exposes hundreds of keys; we surface
   * them all and let the browser's native filter narrow them as the
   * author types.
   */
  get settingNames() {
    return Object.keys(this.siteSettings).sort();
  }

  get currentOperator() {
    for (const op of OPERATORS) {
      if (this.args.leaf?.[op] !== undefined) {
        return op;
      }
    }
    return "enabled";
  }

  get enabledValue() {
    return this.args.leaf?.enabled !== false;
  }

  /**
   * Stringifies the current value for textarea operators (`includes`,
   * `containsAny`) where the schema is an array of strings. One per
   * line is the friendliest input — newlines beat commas because
   * setting values can themselves contain commas.
   */
  get listValueText() {
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
   */
  patch(patch) {
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

  @action
  setName(event) {
    const value = event.target.value;
    this.patch({ name: value || undefined });
  }

  @action
  setOperator(op) {
    // Clear every other operator — the schema enforces exactly one.
    const cleared = {};
    for (const o of OPERATORS) {
      cleared[o] = undefined;
    }
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

  @action
  setEnabled(value) {
    this.patch({ enabled: value });
  }

  @action
  setScalarValue(op, event) {
    const raw = event.target.value;
    this.patch({ [op]: raw });
  }

  @action
  setListValue(op, event) {
    const raw = event.target.value;
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
            value={{@leaf.equals}}
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
