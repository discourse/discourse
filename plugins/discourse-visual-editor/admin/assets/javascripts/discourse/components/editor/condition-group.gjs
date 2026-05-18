// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
import { iconForConditionType } from "../../lib/condition-icons";
import {
  childPath,
  childrenOf,
  combinatorOf,
  isGroup,
} from "../../lib/condition-tree-ops";
import ConditionRule from "./condition-rule";

/**
 * One group node in the conditions tree. Renders a header with the
 * combinator selector + add affordances, and a body of indented
 * children. Children are either nested groups (rendered recursively)
 * or `<ConditionRule>` rows for leaves.
 *
 * The component is self-recursive so nesting depth is unbounded.
 *
 * Args:
 *  - `@node` — the group node (an AND array, an `{any}` object, or
 *     a `{not}` object).
 *  - `@path` — the absolute path from the root tree to this group.
 *  - `@conditionTypes` — registry list used by the type-picker and
 *     the rule rows.
 *  - `@onInsertLeaf(groupPath, typeId)` — handler for the "+ rule"
 *     button. Caller is the `<ConditionsTree>` root.
 *  - `@onInsertGroup(groupPath, combinator)` — handler for the
 *     "+ group" button.
 *  - `@onSetCombinator(path, newCombinator)` — handler for the
 *     combinator chip toggle.
 *  - `@onRemoveNode(path)` — remove this group from its parent.
 *  - `@onUpdateLeaf(path, nextLeaf)` — update a child leaf at the
 *     given path.
 *  - `@isRoot` — true at the root; the root group can't be removed
 *     (clear-all is a separate action).
 *  - `@newlyAddedPath` — the path most recently inserted by the
 *     tree, used to auto-expand that row on its first render. Set
 *     to `null` after the auto-expand fires once.
 */
export default class ConditionGroup extends Component {
  /**
   * Whether a given child path matches the most-recently-inserted
   * path. Compared structurally — `@newlyAddedPath` is an array.
   *
   * @param {Array<string|number>} path
   * @returns {boolean}
   */
  isNewlyAdded = (path) => {
    const target = this.args.newlyAddedPath;
    if (!target || target.length !== path.length) {
      return false;
    }
    for (let i = 0; i < path.length; i++) {
      if (target[i] !== path[i]) {
        return false;
      }
    }
    return true;
  };
  iconFor = (typeId) => iconForConditionType(typeId);
  /**
   * Resolves the registry entry for a leaf node, returning a stub
   * when the type isn't registered so the row renders something.
   */
  metaFor = (leaf) => {
    return (
      this.args.conditionTypes.find((c) => c.type === leaf.type) ?? {
        type: leaf?.type ?? "unknown",
        displayName: leaf?.type ?? i18n("visual_editor.inspector.unknown_type"),
        description: null,
        argsSchema: {},
        sourceType: "none",
        constraints: null,
        namespaceType: "core",
      }
    );
  };
  /**
   * Whether the add-rule picker is currently open. A native
   * `<details>` would also work, but tracking it on the component
   * lets us close the picker as soon as the user clicks a type.
   */
  @tracked _picking = false;

  get combinator() {
    return combinatorOf(this.args.node);
  }

  get children() {
    return childrenOf(this.args.node).map((child, index) => ({
      node: child,
      index,
      path: childPath(this.args.path, this.args.node, index),
      isGroup: isGroup(child),
    }));
  }

  /**
   * Friendly hint surfaced when the group's children list is empty.
   * Spells out the evaluator semantics so the author isn't left
   * guessing why nothing is gating the block.
   */
  get emptyHint() {
    if (this.children.length > 0) {
      return null;
    }
    if (this.combinator === "or") {
      return i18n("visual_editor.inspector.conditions.empty_group_hint_any");
    }
    if (this.combinator === "not") {
      return i18n("visual_editor.inspector.conditions.empty_group_hint_none");
    }
    return i18n("visual_editor.inspector.conditions.empty_group_hint_all");
  }

  @action
  setCombinator(combinator) {
    this.args.onSetCombinator(this.args.path, combinator);
  }

  @action
  togglePicker(event) {
    event.preventDefault();
    event.stopPropagation();
    this._picking = !this._picking;
  }

  @action
  closePicker() {
    this._picking = false;
  }

  @action
  pickType(typeId, event) {
    event.preventDefault();
    event.stopPropagation();
    this._picking = false;
    this.args.onInsertLeaf(this.args.path, typeId);
  }

  @action
  addGroup() {
    this.args.onInsertGroup(this.args.path, "and");
  }

  @action
  removeSelf() {
    this.args.onRemoveNode(this.args.path);
  }

  @action
  removeChild(childPathArg) {
    this.args.onRemoveNode(childPathArg);
  }

  @action
  updateChildLeaf(childPathArg, nextLeaf) {
    this.args.onUpdateLeaf(childPathArg, nextLeaf);
  }

  @action
  changeChildType(childPathArg, typeId) {
    this.args.onUpdateLeaf(childPathArg, { type: typeId });
  }

  <template>
    <div
      class={{dConcatClass
        "visual-editor-condition-group"
        (concat "--" this.combinator)
        (if @isRoot "--root")
      }}
      data-ve-combinator={{this.combinator}}
    >
      <div class="visual-editor-condition-group__header">
        <div
          class="visual-editor-condition-group__combinator-toggle"
          role="radiogroup"
          aria-label={{i18n "visual_editor.inspector.conditions.group_label"}}
        >
          <button
            type="button"
            class={{dConcatClass
              "visual-editor-condition-group__combinator-chip"
              (if (eq this.combinator "and") "--active")
            }}
            role="radio"
            aria-checked={{eq this.combinator "and"}}
            {{on "click" (fn this.setCombinator "and")}}
          >
            {{i18n "visual_editor.inspector.conditions.combinator_all_of"}}
          </button>
          <button
            type="button"
            class={{dConcatClass
              "visual-editor-condition-group__combinator-chip"
              (if (eq this.combinator "or") "--active")
            }}
            role="radio"
            aria-checked={{eq this.combinator "or"}}
            {{on "click" (fn this.setCombinator "or")}}
          >
            {{i18n "visual_editor.inspector.conditions.combinator_any_of"}}
          </button>
          <button
            type="button"
            class={{dConcatClass
              "visual-editor-condition-group__combinator-chip"
              (if (eq this.combinator "not") "--active")
            }}
            role="radio"
            aria-checked={{eq this.combinator "not"}}
            {{on "click" (fn this.setCombinator "not")}}
          >
            {{i18n "visual_editor.inspector.conditions.combinator_none_of"}}
          </button>
        </div>

        {{#unless @isRoot}}
          <button
            type="button"
            class="visual-editor-condition-group__remove"
            title={{i18n "visual_editor.inspector.conditions.remove_group"}}
            {{on "click" this.removeSelf}}
          >
            {{dIcon "xmark"}}
          </button>
        {{/unless}}
      </div>

      <div class="visual-editor-condition-group__body">
        {{#if this.children.length}}
          {{#each this.children as |child|}}
            {{#if child.isGroup}}
              <ConditionGroup
                @node={{child.node}}
                @path={{child.path}}
                @conditionTypes={{@conditionTypes}}
                @onInsertLeaf={{@onInsertLeaf}}
                @onInsertGroup={{@onInsertGroup}}
                @onSetCombinator={{@onSetCombinator}}
                @onRemoveNode={{@onRemoveNode}}
                @onUpdateLeaf={{@onUpdateLeaf}}
                @newlyAddedPath={{@newlyAddedPath}}
                @isRoot={{false}}
              />
            {{else}}
              <ConditionRule
                @node={{child.node}}
                @typeMeta={{this.metaFor child.node}}
                @conditionTypes={{@conditionTypes}}
                @onUpdate={{fn this.updateChildLeaf child.path}}
                @onChangeType={{fn this.changeChildType child.path}}
                @onRemove={{fn this.removeChild child.path}}
                @startExpanded={{this.isNewlyAdded child.path}}
              />
            {{/if}}
          {{/each}}
        {{else}}
          <p class="visual-editor-condition-group__empty-hint">
            {{this.emptyHint}}
          </p>
        {{/if}}

        <div class="visual-editor-condition-group__add">
          <div class="visual-editor-condition-group__add-actions">
            <button
              type="button"
              class={{dConcatClass
                "visual-editor-condition-group__add-rule"
                (if this._picking "--active")
              }}
              aria-expanded={{this._picking}}
              {{on "click" this.togglePicker}}
            >
              {{dIcon "plus"}}
              <span>{{i18n
                  "visual_editor.inspector.conditions.add_rule"
                }}</span>
            </button>

            <button
              type="button"
              class="visual-editor-condition-group__add-group"
              {{on "click" this.addGroup}}
            >
              {{dIcon "object-group"}}
              <span>{{i18n
                  "visual_editor.inspector.conditions.add_group"
                }}</span>
            </button>
          </div>

          {{#if this._picking}}
            <div class="visual-editor-condition-group__type-grid" role="menu">
              {{#each @conditionTypes as |typeMeta|}}
                <button
                  type="button"
                  class="visual-editor-condition-group__type-chip"
                  role="menuitem"
                  title={{typeMeta.description}}
                  {{on "click" (fn this.pickType typeMeta.type)}}
                >
                  {{dIcon (this.iconFor typeMeta.type)}}
                  <span>{{typeMeta.displayName}}</span>
                </button>
              {{/each}}
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
