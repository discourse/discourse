// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

/**
 * Context-sensitive editor for the `outlet-arg` condition. The
 * condition checks a value at a dot-notation path against an
 * `@outletArgs` payload. The schema enforces `exactlyOne` of
 * `value` / `exists`, so the operator switch toggles between three
 * mutually-exclusive surfaces:
 *
 *  - **equals** — a JSON-encoded match value (primitive, array,
 *     regex, or one of the `{not}`/`{any}` shapes the evaluator
 *     understands). The textarea parses on blur; invalid JSON
 *     surfaces an inline error instead of corrupting the schema.
 *  - **exists** — passes when the path resolves to anything other
 *     than `undefined`.
 *  - **missing** — `exists: false`, the inverse check.
 */
export default class OutletArgConditionEditor extends Component {
  @tracked valueJson = serialiseJson(this.args.leaf?.value);
  @tracked valueError = null;

  get currentOperator() {
    if (this.args.leaf?.exists === true) {
      return "exists";
    }
    if (this.args.leaf?.exists === false) {
      return "missing";
    }
    return "equals";
  }

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
  setPath(event) {
    const value = event.target.value;
    this.patch({ path: value || undefined });
  }

  @action
  setOperator(op) {
    if (op === "equals") {
      this.patch({ exists: undefined, value: "" });
      this.valueJson = '""';
      this.valueError = null;
    } else if (op === "exists") {
      this.patch({ exists: true, value: undefined });
    } else {
      this.patch({ exists: false, value: undefined });
    }
  }

  @action
  setValueJson(event) {
    const raw = event.target.value;
    this.valueJson = raw;
    if (raw.trim() === "") {
      this.valueError = null;
      this.patch({ value: undefined });
      return;
    }
    try {
      const parsed = JSON.parse(raw);
      this.valueError = null;
      this.patch({ value: parsed });
    } catch (err) {
      this.valueError = err.message;
    }
  }

  <template>
    <div
      class="wireframe-condition-editor wireframe-condition-editor--outlet-arg"
    >
      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n
            "wireframe.inspector.conditions.outlet_arg_editor.path_legend"
          }}
        </span>
        <input
          type="text"
          value={{@leaf.path}}
          placeholder={{i18n
            "wireframe.inspector.conditions.outlet_arg_editor.path_placeholder"
          }}
          {{on "input" this.setPath}}
        />
        <span class="wireframe-condition-editor__help">
          {{i18n "wireframe.inspector.conditions.outlet_arg_editor.path_help"}}
        </span>
      </div>

      <div class="wireframe-condition-editor__field">
        <span class="wireframe-condition-editor__legend">
          {{i18n
            "wireframe.inspector.conditions.outlet_arg_editor.operator_legend"
          }}
        </span>
        <div class="wireframe-condition-editor__segmented" role="radiogroup">
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.currentOperator "equals") "--active")
            }}
            @ariaPressed={{eq this.currentOperator "equals"}}
            @label="wireframe.inspector.conditions.outlet_arg_editor.operator_equals"
            @action={{fn this.setOperator "equals"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.currentOperator "exists") "--active")
            }}
            @ariaPressed={{eq this.currentOperator "exists"}}
            @label="wireframe.inspector.conditions.outlet_arg_editor.operator_exists"
            @action={{fn this.setOperator "exists"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-editor__segment"
              (if (eq this.currentOperator "missing") "--active")
            }}
            @ariaPressed={{eq this.currentOperator "missing"}}
            @label="wireframe.inspector.conditions.outlet_arg_editor.operator_missing"
            @action={{fn this.setOperator "missing"}}
          />
        </div>
      </div>

      {{#if (eq this.currentOperator "equals")}}
        <div class="wireframe-condition-editor__field">
          <span class="wireframe-condition-editor__legend">
            {{i18n
              "wireframe.inspector.conditions.outlet_arg_editor.value_legend"
            }}
          </span>
          <textarea
            class="wireframe-condition-editor__textarea --mono"
            rows="2"
            placeholder='"open" or {"any": [1, 2, 3]}'
            {{on "input" this.setValueJson}}
          >{{this.valueJson}}</textarea>
          {{#if this.valueError}}
            <span class="wireframe-condition-editor__error">
              {{this.valueError}}
            </span>
          {{else}}
            <span class="wireframe-condition-editor__help">
              {{i18n
                "wireframe.inspector.conditions.outlet_arg_editor.value_help"
              }}
            </span>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}

function serialiseJson(value) {
  if (value === undefined) {
    return "";
  }
  try {
    return JSON.stringify(value);
  } catch {
    return "";
  }
}
