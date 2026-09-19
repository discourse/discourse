import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import dRovingFocus from "discourse/ui-kit/modifiers/d-roving-focus";
import { i18n } from "discourse-i18n";

const NODES = [
  { id: "components", level: 1 },
  { id: "button", level: 2, parent: "components" },
  { id: "select", level: 2, parent: "components" },
  { id: "modifiers", level: 1 },
  { id: "roving_focus", level: 2, parent: "modifiers" },
  { id: "auto_focus", level: 2, parent: "modifiers" },
];

/**
 * Mirrors https://www.w3.org/WAI/ARIA/apg/patterns/treeview/
 *
 * The APG tree pattern in plain semantic HTML. The modifier runs vertically over the visible
 * rows, which is the whole of what it claims here: hierarchy is the consumer's.
 *
 * The cross-axis event implements the tree's four-way contract: forward opens a closed parent
 * or enters an open parent's first child, while backward closes an open parent or returns a
 * child to its parent. The modifier resolves which physical arrow is forward.
 *
 * The consequence is visible in the right-to-left copy: the arrow that points at a row's
 * children is the one that opens them, without this component knowing that writing directions
 * exist.
 *
 * @param dir - Writing direction to render under, either ltr or rtl.
 */
export default class RovingFocusTreeExample extends Component {
  @tracked expanded = { components: true };

  #api = null;

  get rows() {
    return NODES.filter(
      (node) => node.level === 1 || this.expanded[node.parent]
    ).map((node) => ({
      ...node,
      label: i18n(`styleguide.sections.roving_focus.tree.${node.id}`),
      isParent: this.#isParent(node.id),
      expanded: this.expanded[node.id] ? "true" : "false",
    }));
  }

  /**
   * Enter and Space on a parent toggle it. Unlike the cross-axis keys this is safe to route
   * through the modifier, since a row is not a native control and has no activation of its own
   * to lose.
   */
  @action
  activateRow(item) {
    this.#toggle(item.dataset.nodeId);
  }

  @action
  handleClick(event) {
    const row = event.target.closest("[data-node-id]");
    if (row) {
      this.#toggle(row.dataset.nodeId);
    }
  }

  @action
  handleCrossAxis(direction, item) {
    const id = item.dataset.nodeId;
    const isParent = this.#isParent(id);
    const isOpen = Boolean(this.expanded[id]);

    if (direction === "forward") {
      if (isParent && !isOpen) {
        this.#setExpanded(id, true);
        return true;
      }

      if (isParent) {
        const child = this.#api
          ?.items()
          .find((row) => row.dataset.parent === id);
        return child ? this.#api.focusElement(child) : false;
      }

      return false;
    }

    if (isParent && isOpen) {
      this.#setExpanded(id, false);
      return true;
    }

    const parentId = item.dataset.parent;
    if (parentId) {
      const parent = this.#api
        ?.items()
        .find((row) => row.dataset.nodeId === parentId);
      return parent ? this.#api.focusElement(parent) : false;
    }

    return false;
  }

  @action
  registerApi(api) {
    this.#api = api;
  }

  #isParent(id) {
    return NODES.some((node) => node.parent === id);
  }

  #setExpanded(id, next) {
    this.expanded = { ...this.expanded, [id]: next };
  }

  #toggle(id) {
    if (this.#isParent(id)) {
      this.#setExpanded(id, !this.expanded[id]);
    }
  }

  <template>
    <ul
      aria-label={{i18n "styleguide.sections.roving_focus.tree.label"}}
      class="roving-demo__tree"
      dir={{@dir}}
      role="tree"
      {{on "click" this.handleClick}}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".roving-demo__row"
        entryFocus="selected-or-first"
        onActivate=this.activateRow
        onCrossAxis=this.handleCrossAxis
        onRegisterApi=this.registerApi
      }}
    >
      {{#each this.rows key="id" as |row|}}
        <li
          aria-expanded={{if row.isParent row.expanded}}
          aria-level={{row.level}}
          class="roving-demo__row"
          data-node-id={{row.id}}
          data-parent={{row.parent}}
          role="treeitem"
        >
          {{row.label}}
        </li>
      {{/each}}
    </ul>
  </template>
}
