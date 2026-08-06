import Component from "@glimmer/component";
import { TrustedHTML, trustHTML } from "@ember/template";
import type { BlockEntry } from "discourse/lib/blocks/-internals/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { formatValue } from "../lib/value-formatter";

/**
 * A single node in the hierarchical condition tree produced by
 * `#formatCondition()`, ready for rendering by `ConditionNode`.
 */
interface FormattedConditionNode {
  /** Condition type, or combinator (AND/OR/NOT). */
  type: string;
  /** Nesting depth for indentation. */
  depth: number;
  /** Nested nodes, for combinator nodes. */
  children?: FormattedConditionNode[];
  /** Remaining condition arguments, for leaf nodes. */
  args?: Record<string, unknown> | null;
  /** True for leaf (non-combinator) condition nodes. */
  isLeaf?: boolean;
}

interface ConditionsTreeSignature {
  Args: {
    /** The conditions to display. */
    conditions?: BlockEntry["conditions"];
    /** Whether the conditions passed overall. */
    passed: boolean;
  };
}

/**
 * Displays condition hierarchy with pass/fail indicators.
 */
export default class ConditionsTree extends Component<ConditionsTreeSignature> {
  /**
   * Transforms the raw conditions object/array into a hierarchical array of
   * formatted nodes for rendering. This is the entry point for the recursive
   * formatting. Each node may contain a `children` array for nested conditions.
   *
   * @returns An array of condition nodes ready for rendering.
   */
  get formattedConditions(): FormattedConditionNode[] {
    return this.#formatCondition(this.args.conditions, 0);
  }

  /**
   * Recursively transforms a condition structure into a hierarchical array of nodes.
   * Each combinator node (AND/OR/NOT) contains a `children` array with nested nodes.
   * Handles four types of input:
   * - Array: Treated as AND logic, wraps children in an AND combinator node.
   * - Object with `any`: OR combinator, children are the `any` array items.
   * - Object with `not`: NOT combinator, child is the negated condition.
   * - Object with `type`: Leaf condition node with optional arguments.
   *
   * @param condition - The condition to format.
   * @param depth - The nesting depth for indentation calculation.
   * @returns An array of formatted condition nodes.
   */
  #formatCondition(
    condition: object | object[] | null | undefined,
    depth: number
  ): FormattedConditionNode[] {
    if (!condition) {
      return [];
    }

    const items: FormattedConditionNode[] = [];

    // Array of conditions (AND logic) - all conditions must pass
    if (Array.isArray(condition)) {
      items.push({
        type: "AND",
        depth,
        children: condition.flatMap((c) => this.#formatCondition(c, depth + 1)),
      });
      return items;
    }

    // OR combinator - at least one condition must pass
    const anySpec = (condition as { any?: object[] }).any;
    if (anySpec !== undefined) {
      items.push({
        type: "OR",
        depth,
        children: anySpec.flatMap((c) => this.#formatCondition(c, depth + 1)),
      });
      return items;
    }

    // NOT combinator - inverts the result of the nested condition
    const notSpec = (condition as { not?: object }).not;
    if (notSpec !== undefined) {
      items.push({
        type: "NOT",
        depth,
        children: this.#formatCondition(notSpec, depth + 1),
      });
      return items;
    }

    // Single condition with type (leaf node) - extract type and remaining args
    const { type, ...args } = condition as { type: string } & Record<
      string,
      unknown
    >;
    items.push({
      type,
      args: Object.keys(args).length > 0 ? args : null,
      depth,
      isLeaf: true,
    });

    return items;
  }

  <template>
    <div
      class={{dConcatClass
        "block-debug-conditions"
        (if @passed "--passed" "--failed")
      }}
    >
      {{#each this.formattedConditions as |item|}}
        <ConditionNode @item={{item}} @passed={{@passed}} />
      {{/each}}
    </div>
  </template>
}

interface ConditionNodeSignature {
  Args: {
    /** The condition node data from `#formatCondition()`. */
    item: FormattedConditionNode;
    /** Whether the overall conditions passed. */
    passed: boolean;
  };
}

/**
 * Renders a single condition node in the tree.
 * Handles both combinator nodes (AND, OR, NOT) and leaf condition nodes.
 */
class ConditionNode extends Component<ConditionNodeSignature> {
  /**
   * Formatting options for condition argument values.
   * Enables expanded arrays, symbols, and RegExp handling for readable output.
   */
  static FORMAT_OPTIONS = {
    expandArrays: true,
    handleSymbols: true,
    handleRegExp: true,
  };

  /**
   * Calculates the CSS padding for indentation based on the node's depth.
   * Each level adds 12px of left padding.
   *
   * @returns CSS style string for padding, marked as safe for binding.
   */
  get indentStyle(): TrustedHTML {
    return trustHTML(`padding-left: ${this.args.item.depth * 12}px`);
  }

  /**
   * Checks if this node is a boolean combinator (AND, OR, NOT) rather than
   * a leaf condition. Combinators are styled differently in the UI.
   *
   * @returns True if this is a combinator node.
   */
  get isCombinator(): boolean {
    return ["AND", "OR", "NOT"].includes(this.args.item.type);
  }

  /**
   * Formats the condition's arguments as a comma-separated string for display.
   * Returns null if there are no arguments to display.
   *
   * @returns Formatted arguments string, or null if no arguments.
   */
  get argsDisplay(): string | null {
    const args = this.args.item.args;
    if (!args) {
      return null;
    }
    return Object.entries(args)
      .map(([k, v]) => `${k}: ${formatValue(v, ConditionNode.FORMAT_OPTIONS)}`)
      .join(", ");
  }

  <template>
    <div
      class={{dConcatClass
        "block-debug-condition"
        (if this.isCombinator "--combinator" "--leaf")
      }}
      style={{this.indentStyle}}
    >
      {{#if this.isCombinator}}
        <span class="block-debug-condition__type --combinator">
          {{@item.type}}
        </span>
      {{else}}
        <span class="block-debug-condition__type">{{@item.type}}</span>
        {{#if this.argsDisplay}}
          <span
            class="block-debug-condition__args"
          >({{this.argsDisplay}})</span>
        {{/if}}
      {{/if}}
    </div>
    {{#if @item.children}}
      {{#each @item.children as |child|}}
        <ConditionNode @item={{child}} @passed={{@passed}} />
      {{/each}}
    {{/if}}
  </template>
}
