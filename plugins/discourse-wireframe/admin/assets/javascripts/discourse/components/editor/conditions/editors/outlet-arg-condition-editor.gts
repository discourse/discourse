import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import type { ConditionLeaf } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";

type OutletArgOperator = "equals" | "exists" | "missing";

type OutletArgConditionLeaf = ConditionLeaf & {
  /** Dot-delimited path resolved from outlet arguments. */
  path?: string;
  /** Value matched at the resolved path. */
  value?: unknown;
  /** Whether the resolved path must exist. */
  exists?: boolean;
};

interface OutletArgConditionEditorSignature {
  /** Outlet-argument condition and update callback. */
  Args: {
    /** Outlet-argument condition leaf being edited. */
    leaf: OutletArgConditionLeaf;
    /** Replaces the edited condition leaf. */
    onChange: (
      /** Updated outlet-argument condition leaf. */
      leaf: OutletArgConditionLeaf
    ) => void;
  };
}

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
export default class OutletArgConditionEditor extends Component<OutletArgConditionEditorSignature> {
  /** Editable JSON representation of the match value. */
  @tracked valueJson: string | undefined = serialiseJson(this.args.leaf?.value);
  /** Current JSON parse error. */
  @tracked valueError: string | null = null;

  /** Operator represented by the current leaf fields. */
  get currentOperator(): OutletArgOperator {
    if (this.args.leaf?.exists === true) {
      return "exists";
    }
    if (this.args.leaf?.exists === false) {
      return "missing";
    }
    return "equals";
  }

  /**
   * Applies a partial leaf update, deleting undefined fields.
   *
   * @param patch - Condition fields to replace or remove.
   */
  patch(patch: Partial<OutletArgConditionLeaf>): void {
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
   * Updates the outlet-argument path.
   *
   * @param event - Path-input event.
   */
  @action
  setPath(event: Event): void {
    if (!(event.currentTarget instanceof HTMLInputElement)) {
      return;
    }
    const value = event.currentTarget.value;
    this.patch({ path: value || undefined });
  }

  /**
   * Switches the mutually exclusive condition operator.
   *
   * @param op - Operator selected by the author.
   */
  @action
  setOperator(op: OutletArgOperator): void {
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

  /**
   * Parses and applies an edited JSON match value.
   *
   * @param event - Value-textarea input event.
   */
  @action
  setValueJson(event: Event): void {
    if (!(event.currentTarget instanceof HTMLTextAreaElement)) {
      return;
    }
    const raw = event.currentTarget.value;
    this.valueJson = raw;
    if (raw.trim() === "") {
      this.valueError = null;
      this.patch({ value: undefined });
      return;
    }
    try {
      const parsed: unknown = JSON.parse(raw);
      this.valueError = null;
      this.patch({ value: parsed });
    } catch (error) {
      this.valueError = error instanceof Error ? error.message : String(error);
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

/**
 * Serializes a condition value for the JSON editor.
 *
 * @param value - Condition value to serialize.
 * @returns Serialized JSON, or an empty string when unavailable.
 */
function serialiseJson(value: unknown): string | undefined {
  if (value === undefined) {
    return "";
  }
  try {
    return JSON.stringify(value);
  } catch {
    return "";
  }
}
