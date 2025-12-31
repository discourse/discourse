import Component from "@glimmer/component";
import concatClass from "discourse/helpers/concat-class";

/**
 * Displays condition hierarchy with pass/fail indicators.
 *
 * @component ConditionsTree
 * @param {Object|Array} conditions - The conditions to display
 * @param {boolean} passed - Whether the conditions passed overall
 */
export default class ConditionsTree extends Component {
  get formattedConditions() {
    return this.#formatCondition(this.args.conditions, 0);
  }

  #formatCondition(condition, depth) {
    if (!condition) {
      return [];
    }

    const items = [];

    // Array of conditions (AND logic)
    if (Array.isArray(condition)) {
      items.push({
        type: "AND",
        depth,
        children: condition.flatMap((c) => this.#formatCondition(c, depth + 1)),
      });
      return items;
    }

    // OR combinator
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

    // NOT combinator
    if (condition.not !== undefined) {
      items.push({
        type: "NOT",
        depth,
        children: this.#formatCondition(condition.not, depth + 1),
      });
      return items;
    }

    // Single condition with type
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
 */
class ConditionNode extends Component {
  get indentStyle() {
    return `padding-left: ${this.args.item.depth * 12}px`;
  }

  get isCombinator() {
    return ["AND", "OR", "NOT"].includes(this.args.item.type);
  }

  get argsDisplay() {
    const args = this.args.item.args;
    if (!args) {
      return null;
    }
    return Object.entries(args)
      .map(([k, v]) => `${k}: ${this.#formatValue(v)}`)
      .join(", ");
  }

  #formatValue(value) {
    if (typeof value === "symbol") {
      return `Symbol(${value.description || ""})`;
    }
    if (Array.isArray(value)) {
      return `[${value.map((v) => this.#formatValue(v)).join(", ")}]`;
    }
    if (value instanceof RegExp) {
      return value.toString();
    }
    return JSON.stringify(value);
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
