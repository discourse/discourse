// @ts-check
import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { concat, fn } from "@ember/helper";
import { action } from "@ember/object";
import { eq } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";
import ConditionRule from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-rule";
import { iconForConditionType } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-icons";
import {
  childPath,
  childrenOf,
  combinatorOf,
  isGroup,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree-ops";

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
   * Whether the add-rule picker is currently open. A native
   * `<details>` would also work, but tracking it on the component
   * lets us close the picker as soon as the user clicks a type.
   */
  @tracked picking = false;
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
        displayName: leaf?.type ?? i18n("wireframe.inspector.unknown_type"),
        description: null,
        argsSchema: {},
        sourceType: "none",
        constraints: null,
        namespaceType: "core",
      }
    );
  };

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
      return i18n("wireframe.inspector.conditions.empty_group_hint_any");
    }
    if (this.combinator === "not") {
      return i18n("wireframe.inspector.conditions.empty_group_hint_none");
    }
    return i18n("wireframe.inspector.conditions.empty_group_hint_all");
  }

  @action
  setCombinator(combinator) {
    this.args.onSetCombinator(this.args.path, combinator);
  }

  @action
  togglePicker() {
    this.picking = !this.picking;
  }

  @action
  closePicker() {
    this.picking = false;
  }

  @action
  pickType(typeId) {
    this.picking = false;
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
        "wireframe-condition-group"
        (concat "--" this.combinator)
        (if @isRoot "--root")
      }}
      data-wf-combinator={{this.combinator}}
    >
      <div class="wireframe-condition-group__header">
        <div
          class="wireframe-condition-group__combinator-toggle"
          role="radiogroup"
          aria-label={{i18n "wireframe.inspector.conditions.group_label"}}
        >
          <DButton
            class={{dConcatClass
              "wireframe-condition-group__combinator-chip"
              (if (eq this.combinator "and") "--active")
            }}
            @ariaPressed={{eq this.combinator "and"}}
            @label="wireframe.inspector.conditions.combinator_all_of"
            @action={{fn this.setCombinator "and"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-group__combinator-chip"
              (if (eq this.combinator "or") "--active")
            }}
            @ariaPressed={{eq this.combinator "or"}}
            @label="wireframe.inspector.conditions.combinator_any_of"
            @action={{fn this.setCombinator "or"}}
          />
          <DButton
            class={{dConcatClass
              "wireframe-condition-group__combinator-chip"
              (if (eq this.combinator "not") "--active")
            }}
            @ariaPressed={{eq this.combinator "not"}}
            @label="wireframe.inspector.conditions.combinator_none_of"
            @action={{fn this.setCombinator "not"}}
          />
        </div>

        {{#unless @isRoot}}
          <DButton
            class="wireframe-condition-group__remove"
            @icon="xmark"
            @title="wireframe.inspector.conditions.remove_group"
            @action={{this.removeSelf}}
          />
        {{/unless}}
      </div>

      <div class="wireframe-condition-group__body">
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
          <p class="wireframe-condition-group__empty-hint">
            {{this.emptyHint}}
          </p>
        {{/if}}

        <div class="wireframe-condition-group__add">
          <div class="wireframe-condition-group__add-actions">
            <DButton
              class={{dConcatClass
                "wireframe-condition-group__add-rule"
                (if this.picking "--active")
              }}
              @ariaExpanded={{this.picking}}
              @icon="plus"
              @label="wireframe.inspector.conditions.add_rule"
              @action={{this.togglePicker}}
            />

            <DButton
              class="wireframe-condition-group__add-group"
              @icon="object-group"
              @label="wireframe.inspector.conditions.add_group"
              @action={{this.addGroup}}
            />
          </div>

          {{#if this.picking}}
            <div class="wireframe-condition-group__type-grid" role="menu">
              {{#each @conditionTypes as |typeMeta|}}
                <DButton
                  class="wireframe-condition-group__type-chip"
                  role="menuitem"
                  @icon={{this.iconFor typeMeta.type}}
                  @translatedLabel={{typeMeta.displayName}}
                  @translatedTitle={{typeMeta.description}}
                  @action={{fn this.pickType typeMeta.type}}
                />
              {{/each}}
            </div>
          {{/if}}
        </div>
      </div>
    </div>
  </template>
}
