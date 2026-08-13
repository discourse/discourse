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
 * The APG tree pattern in plain semantic HTML. The modifier runs vertically over the visible
 * rows, which is the whole of what it claims here: hierarchy is the consumer's.
 *
 * Expand and collapse are hand-rolled below, on a sibling keydown handler, because a vertical
 * group leaves the horizontal arrows un-prevented and the modifier emits no cross-axis event yet.
 * That handler reads the physical key, so rendering this same component under a right-to-left
 * direction is the experiment: the arrow that points at a row's children stops agreeing with the
 * arrow that opens it. Resolving the direction logically rather than physically is what a
 * cross-axis event would move into the modifier and out of here.
 *
 * @param dir - Writing direction to render under, either ltr or rtl.
 */
export default class RovingFocusTreeExample extends Component {
  @tracked expanded = { components: true };

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
  handleCrossAxisKeys(event) {
    if (event.key !== "ArrowRight" && event.key !== "ArrowLeft") {
      return;
    }
    const row = event.target.closest("[data-node-id]");
    if (!row || !this.#isParent(row.dataset.nodeId)) {
      return;
    }
    this.#setExpanded(row.dataset.nodeId, event.key === "ArrowRight");
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
      class="roving-demo__tree"
      dir={{@dir}}
      role="tree"
      aria-label={{i18n "styleguide.sections.roving_focus.tree.label"}}
      {{on "keydown" this.handleCrossAxisKeys}}
      {{on "click" this.handleClick}}
      {{dRovingFocus
        orientation="vertical"
        itemSelector=".roving-demo__row"
        entryFocus="selected-or-first"
        onActivate=this.activateRow
      }}
    >
      {{#each this.rows key="id" as |row|}}
        <li
          class="roving-demo__row"
          role="treeitem"
          data-node-id={{row.id}}
          aria-level={{row.level}}
          aria-expanded={{if row.isParent row.expanded}}
        >
          {{row.label}}
        </li>
      {{/each}}
    </ul>
  </template>
}
