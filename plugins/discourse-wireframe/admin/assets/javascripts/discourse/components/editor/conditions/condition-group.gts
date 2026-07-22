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
import type {
  ConditionCombinator,
  ConditionGroup as ConditionGroupNode,
  ConditionLeaf,
  ConditionPath,
  ConditionTypeMeta,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";
import {
  childPath,
  childrenOf,
  combinatorOf,
  isGroup,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree-ops";

type ConditionGroupChild =
  | {
      /** Nested combinator represented by this child. */
      group: ConditionGroupNode;
      /** Group children do not carry a leaf. */
      leaf?: never;
      /** Child index in the group's normalized child list. */
      index: number;
      /** Absolute path to the child. */
      path: ConditionPath;
    }
  | {
      /** Leaf children do not carry a nested combinator. */
      group?: never;
      /** Nested condition represented by this child. */
      leaf: ConditionLeaf;
      /** Child index in the group's normalized child list. */
      index: number;
      /** Absolute path to the child. */
      path: ConditionPath;
    };

interface ConditionGroupSignature {
  /** Condition group state and tree mutation callbacks. */
  Args: {
    /** Combinator node rendered by this group. */
    node: ConditionGroupNode;
    /** Absolute path to the group. */
    path: ConditionPath;
    /** Registered condition descriptors. */
    conditionTypes: ConditionTypeMeta[];
    /** Inserts a leaf into a group. */
    onInsertLeaf: (
      /** Path to the target group. */
      groupPath: ConditionPath,
      /** Registered condition type to insert. */
      typeId: string
    ) => void;
    /** Inserts a nested combinator into a group. */
    onInsertGroup: (
      /** Path to the target group. */
      groupPath: ConditionPath,
      /** Combinator to insert. */
      combinator: ConditionCombinator
    ) => void;
    /** Replaces a group's combinator. */
    onSetCombinator: (
      /** Path to the target group. */
      path: ConditionPath,
      /** Replacement combinator. */
      newCombinator: ConditionCombinator
    ) => void;
    /** Removes a node from the tree. */
    onRemoveNode: (
      /** Path to the node to remove. */
      path: ConditionPath
    ) => void;
    /** Replaces a leaf in the tree. */
    onUpdateLeaf: (
      /** Path to the leaf to replace. */
      path: ConditionPath,
      /** Replacement leaf. */
      nextLeaf: ConditionLeaf
    ) => void;
    /** Whether this group is the root node. */
    isRoot: boolean;
    /** Most recently inserted node path, used for initial expansion. */
    newlyAddedPath: ConditionPath | null;
  };
}

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
export default class ConditionGroup extends Component<ConditionGroupSignature> {
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
   * @param path - Absolute child path to compare.
   * @returns Whether the child was most recently inserted.
   */
  isNewlyAdded: (path: ConditionPath) => boolean = (path) => {
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
  /**
   * Resolves the icon for a condition type.
   *
   * @param typeId - Registered condition type identifier.
   * @returns Icon identifier for the condition type.
   */
  iconFor: (typeId: string) => string = (typeId) =>
    iconForConditionType(typeId);

  /**
   * Resolves the registry entry for a leaf node, returning a stub
   * when the type isn't registered so the row renders something.
   *
   * @param leaf - Condition leaf to describe.
   * @returns Registered metadata or a display-safe fallback.
   */
  metaFor: (leaf: ConditionLeaf) => ConditionTypeMeta = (leaf) => {
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

  /** Combinator represented by this group node. */
  get combinator(): ConditionCombinator | null {
    return combinatorOf(this.args.node);
  }

  /** Normalized child nodes paired with their absolute paths. */
  get children(): ConditionGroupChild[] {
    return childrenOf(this.args.node).map(
      (child, index): ConditionGroupChild => {
        const path = childPath(this.args.path, this.args.node, index);
        return isGroup(child)
          ? { group: child, index, path }
          : { leaf: child, index, path };
      }
    );
  }

  /**
   * Friendly hint surfaced when the group's children list is empty.
   * Spells out the evaluator semantics so the author isn't left
   * guessing why nothing is gating the block.
   */
  get emptyHint(): string | null {
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

  /**
   * Replaces this group's combinator.
   *
   * @param combinator - Replacement combinator.
   */
  @action
  setCombinator(combinator: ConditionCombinator): void {
    this.args.onSetCombinator(this.args.path, combinator);
  }

  /** Toggles the add-rule picker. */
  @action
  togglePicker(): void {
    this.picking = !this.picking;
  }

  /** Closes the add-rule picker. */
  @action
  closePicker(): void {
    this.picking = false;
  }

  /**
   * Inserts a rule of the selected condition type.
   *
   * @param typeId - Registered condition type identifier.
   */
  @action
  pickType(typeId: string): void {
    this.picking = false;
    this.args.onInsertLeaf(this.args.path, typeId);
  }

  /** Inserts a nested AND group. */
  @action
  addGroup(): void {
    this.args.onInsertGroup(this.args.path, "and");
  }

  /** Removes this group from its parent. */
  @action
  removeSelf(): void {
    this.args.onRemoveNode(this.args.path);
  }

  /**
   * Removes one direct child.
   *
   * @param childPathArg - Absolute path to the child.
   */
  @action
  removeChild(childPathArg: ConditionPath): void {
    this.args.onRemoveNode(childPathArg);
  }

  /**
   * Replaces one direct child leaf.
   *
   * @param childPathArg - Absolute path to the child.
   * @param nextLeaf - Replacement condition leaf.
   */
  @action
  updateChildLeaf(childPathArg: ConditionPath, nextLeaf: ConditionLeaf): void {
    this.args.onUpdateLeaf(childPathArg, nextLeaf);
  }

  /**
   * Replaces a child leaf with a fresh leaf of another type.
   *
   * @param childPathArg - Absolute path to the child.
   * @param typeId - Replacement condition type identifier.
   */
  @action
  changeChildType(childPathArg: ConditionPath, typeId: string): void {
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
            {{#if child.group}}
              <ConditionGroup
                @node={{child.group}}
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
                @node={{child.leaf}}
                @typeMeta={{this.metaFor child.leaf}}
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
