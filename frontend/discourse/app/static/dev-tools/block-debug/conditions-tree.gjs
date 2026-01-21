// @ts-check
import Component from "@glimmer/component";
import { htmlSafe } from "@ember/template";
import concatClass from "discourse/helpers/concat-class";
import { formatValue } from "../lib/value-formatter";

/**
 * Displays condition hierarchy with pass/fail indicators.
 *
 * @param {Object|Array} conditions - The conditions to display
 * @param {boolean} passed - Whether the conditions passed overall
 */
export default class ConditionsTree extends Component {
  /**
   * Transforms the raw conditions object/array into a flat array of formatted
   * nodes for rendering. This is the entry point for the recursive formatting.
   *
   * @returns {Array<Object>} An array of condition nodes ready for rendering.
   */
  get formattedConditions() {
    return this.#formatCondition(this.args.conditions, 0);
  }

  /**
   * Recursively transforms a condition structure into a flat array of renderable nodes.
   * Handles four types of input:
   * - Array: Treated as AND logic, wraps children in an AND combinator node.
   * - Object with `any`: OR combinator, children are the `any` array items.
   * - Object with `not`: NOT combinator, child is the negated condition.
   * - Object with `type`: Leaf condition node with optional arguments.
   *
   * @param {Object|Array|null} condition - The condition to format.
   * @param {number} depth - The nesting depth for indentation calculation.
   * @returns {Array<Object>} An array of formatted condition nodes.
   */
  #formatCondition(condition, depth) {
    if (!condition) {
      return [];
    }

    const items = [];

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
    if (condition.any !== undefined) {
      items.push({
        type: "OR",
        depth,
        children: condition.any.flatMap((c) =>
          this.#formatCondition(c, depth + 1)
        ),
      });
      return items;
    }

    // NOT combinator - inverts the result of the nested condition
    if (condition.not !== undefined) {
      items.push({
        type: "NOT",
        depth,
        children: this.#formatCondition(condition.not, depth + 1),
      });
      return items;
    }

    // Single condition with type (leaf node) - extract type and remaining args
    const { type, ...args } = condition;
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
      class={{concatClass
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

/**
 * Renders a single condition node in the tree.
 * Handles both combinator nodes (AND, OR, NOT) and leaf condition nodes.
 *
 * @param {Object} item - The condition node data from #formatCondition.
 * @param {boolean} passed - Whether the overall conditions passed.
 */
class ConditionNode extends Component {
  /**
   * Formatting options for condition argument values.
   * Enables expanded arrays, symbols, and RegExp handling for readable output.
   *
   * @constant {Object}
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
   * @returns {ReturnType<typeof htmlSafe>} CSS style string for padding, marked as safe for binding.
   */
  get indentStyle() {
    return htmlSafe(`padding-left: ${this.args.item.depth * 12}px`);
  }

  /**
   * Checks if this node is a boolean combinator (AND, OR, NOT) rather than
   * a leaf condition. Combinators are styled differently in the UI.
   *
   * @returns {boolean} True if this is a combinator node.
   */
  get isCombinator() {
    return ["AND", "OR", "NOT"].includes(this.args.item.type);
  }

  /**
   * Formats the condition's arguments as a comma-separated string for display.
   * Returns null if there are no arguments to display.
   *
   * @returns {string|null} Formatted arguments string, or null if no arguments.
   */
  get argsDisplay() {
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
      class={{concatClass
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
