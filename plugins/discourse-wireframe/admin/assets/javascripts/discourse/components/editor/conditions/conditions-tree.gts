import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import type BlocksService from "discourse/services/blocks";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import ConditionGroup from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-group";
import ConditionRule from "discourse/plugins/discourse-wireframe/discourse/components/editor/conditions/condition-rule";
import { iconForConditionType } from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-icons";
import {
  classifyNode,
  type ConditionCombinator,
  type ConditionGroup as ConditionGroupNode,
  type ConditionLeaf,
  type ConditionPath,
  type ConditionTree,
  type ConditionTypeMeta,
  isConditionTree,
  readAt,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree";
import {
  insertGroup,
  insertLeaf,
  isGroup,
  isLeaf,
  removeAt,
  setCombinator,
  updateLeaf,
} from "discourse/plugins/discourse-wireframe/discourse/lib/conditions/condition-tree-ops";
import type WireframeEntryConfigService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-entry-config";
import type WireframeSelectionService from "discourse/plugins/discourse-wireframe/discourse/services/wireframe-selection";

/**
 * Top-level conditions surface. Renders a QueryBuilder-style tree of
 * groups and rules; new rules expand inline (no popover, no
 * z-index fight).
 *
 * The tree shape itself is unchanged (`[a, b]` / `{any}` / `{not}` /
 * `{type, ...args}`). Every mutation routes through
 * `wireframeEntryConfig.updateSelectedConditions`, so each edit lands on the
 * structural undo stack.
 *
 * Display normalisation:
 *  - `null` → empty-state with a "+ Add condition" CTA.
 *  - A bare leaf at the root → rendered as a single rule row (no
 *     surrounding group header).
 *  - Anything else → a `<ConditionGroup>` rendered as the root.
 */
export default class ConditionsTree extends Component {
  /** Commits condition-tree changes to the selected entry. */
  @service declare wireframeEntryConfig: WireframeEntryConfigService;

  /** Provides the selected entry's live condition tree. */
  @service declare wireframeSelection: WireframeSelectionService;

  /** Provides registered condition descriptors. */
  @service declare blocks: BlocksService;

  /**
   * Path of the most-recently-inserted node. `<ConditionGroup>` reads
   * this to start the matching child in the expanded state on its
   * first render — so authors immediately see the editor without
   * having to click the row again.
   *
   * Set by `handleInsertLeaf` / `seedFromEmpty`; cleared on every
   * non-insert mutation so stale paths don't keep re-expanding rows.
   *
   */
  @tracked newlyAddedPath: ConditionPath | null = null;

  /** Root path passed to the root condition group. */
  emptyPath: ConditionPath = [];

  /**
   * Resolves the icon for a condition type.
   *
   * @param typeId - Registered condition type identifier.
   * @returns Icon identifier for the condition type.
   */
  iconFor: (typeId: string) => string = (typeId) =>
    iconForConditionType(typeId);

  /**
   * Resolves metadata for a leaf, falling back for unknown types.
   *
   * @param leaf - Condition leaf to describe.
   * @returns Registered metadata or a display-safe fallback.
   */
  metaFor: (leaf: ConditionLeaf | undefined) => ConditionTypeMeta = (leaf) => {
    return (
      this.conditionTypes.find((c) => c.type === leaf?.type) ?? {
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

  /**
   * The current conditions tree for the selected block. Returns the
   * service's live tracked tree so mutations propagate without an
   * explicit subscription.
   *
   * @returns The current condition tree.
   */
  @cached
  get tree(): ConditionTree {
    const tree = this.wireframeSelection.selectedBlockConditions;
    return isConditionTree(tree) ? tree : null;
  }

  /**
   * Registered condition types from the blocks service. Drives the
   * "Add rule" picker.
   *
   * @returns Registered condition descriptors.
   */
  @cached
  get conditionTypes(): ConditionTypeMeta[] {
    return this.blocks.listConditionTypes();
  }

  /**
   * `true` when the tree contains no rules — drives the empty-state
   * placeholder.
   *
   * @returns Whether the tree is empty.
   */
  get isEmpty(): boolean {
    return classifyNode(this.tree) === "empty";
  }

  /** Root leaf, or `undefined` when the root is not a leaf. */
  get rootLeaf(): ConditionLeaf | undefined {
    return isLeaf(this.tree) ? this.tree : undefined;
  }

  /** Root combinator, or `undefined` when the root is not a group. */
  get rootGroup(): ConditionGroupNode | undefined {
    return isGroup(this.tree) ? this.tree : undefined;
  }

  /**
   * Commits a new tree to the editor service. Conditions are
   * structural, so the change lands on the undo stack alongside drag
   * / insert / remove mutations.
   *
   * @param next - Replacement condition tree.
   */
  commit(next: ConditionTree): void {
    this.wireframeEntryConfig.updateSelectedConditions(next ?? null);
  }

  /**
   * Inserts a condition leaf into a group.
   *
   * @param groupPath - Absolute path to the target group.
   * @param typeId - Registered condition type identifier.
   */
  @action
  handleInsertLeaf(groupPath: ConditionPath, typeId: string): void {
    this.#markNewlyAddedFor(groupPath);
    this.commit(insertLeaf(this.tree ?? [], groupPath, typeId));
  }

  /**
   * Inserts a nested condition group.
   *
   * @param groupPath - Absolute path to the target group.
   * @param combinator - Combinator for the nested group.
   */
  @action
  handleInsertGroup(
    groupPath: ConditionPath,
    combinator: ConditionCombinator
  ): void {
    this.newlyAddedPath = null;
    this.commit(insertGroup(this.tree ?? [], groupPath, combinator));
  }

  /**
   * Replaces a group's combinator.
   *
   * @param path - Absolute path to the group.
   * @param newCombinator - Replacement combinator.
   */
  @action
  handleSetCombinator(
    path: ConditionPath,
    newCombinator: ConditionCombinator
  ): void {
    this.newlyAddedPath = null;
    this.commit(setCombinator(this.tree, path, newCombinator));
  }

  /**
   * Removes a condition node.
   *
   * @param path - Absolute path to the node.
   */
  @action
  handleRemoveNode(path: ConditionPath): void {
    this.newlyAddedPath = null;
    this.commit(removeAt(this.tree, path));
  }

  /**
   * Replaces a condition leaf.
   *
   * @param path - Absolute path to the leaf.
   * @param nextLeaf - Replacement condition leaf.
   */
  @action
  handleUpdateLeaf(path: ConditionPath, nextLeaf: ConditionLeaf): void {
    this.newlyAddedPath = null;
    this.commit(updateLeaf(this.tree, path, nextLeaf));
  }

  /**
   * Replaces the root leaf.
   *
   * @param nextLeaf - Replacement condition leaf.
   */
  @action
  handleRootLeafUpdate(nextLeaf: ConditionLeaf): void {
    this.newlyAddedPath = null;
    this.commit(nextLeaf);
  }

  /**
   * Changes the root leaf's condition type.
   *
   * @param typeId - Replacement condition type identifier.
   */
  @action
  handleRootLeafChangeType(typeId: string): void {
    this.newlyAddedPath = null;
    this.commit({ type: typeId });
  }

  /** Removes the root leaf. */
  @action
  handleRootLeafRemove(): void {
    this.newlyAddedPath = null;
    this.commit(null);
  }

  /**
   * Creates the first condition rule.
   *
   * @param typeId - Registered condition type identifier.
   */
  @action
  seedFromEmpty(typeId: string): void {
    // Seed in the array (AND) form so the freshly-seeded tree carries
    // a group header — the user can immediately add more rules from
    // the same surface. Mark the new rule for auto-expansion.
    this.newlyAddedPath = [0];
    this.commit([{ type: typeId }]);
  }

  /** Clears the entire condition tree. */
  @action
  clearAll(): void {
    this.newlyAddedPath = null;
    this.commit(null);
  }

  /**
   * Computes the path of the rule that the next render will need to
   * auto-expand. The path uses condition-tree's segment convention
   * (numeric index for AND children, `"any"` + index for OR,
   * `"not"` or `"not"` + index for NOT).
   *
   * Called BEFORE `commit()` so it reflects the tree shape we're
   * about to write.
   *
   * @param groupPath - Absolute path to the insertion group.
   */
  #markNewlyAddedFor(groupPath: ConditionPath): void {
    const tree = this.tree ?? [];
    const group = groupPath.length === 0 ? tree : readAt(tree, groupPath);
    if (!group) {
      this.newlyAddedPath = null;
      return;
    }
    const kind = classifyNode(group);
    if (kind === "and" && Array.isArray(group)) {
      this.newlyAddedPath = [...groupPath, group.length];
      return;
    }
    if (kind === "or") {
      const children = Reflect.get(group, "any");
      if (!Array.isArray(children)) {
        this.newlyAddedPath = null;
        return;
      }
      this.newlyAddedPath = [...groupPath, "any", children.length];
      return;
    }
    if (kind === "not") {
      const child = Reflect.get(group, "not");
      if (Array.isArray(child)) {
        this.newlyAddedPath = [...groupPath, "not", child.length];
        return;
      }
      // Empty NOT case never happens (newEmptyGroup seeds with a leaf)
      // but if it did, promotion would put the new leaf at index 1.
      this.newlyAddedPath = [...groupPath, "not", 1];
      return;
    }
    this.newlyAddedPath = null;
  }

  <template>
    <div class="wireframe-conditions-tree">
      {{#if this.isEmpty}}
        <div class="wireframe-conditions-tree__empty">
          <p class="wireframe-conditions-tree__hint">
            {{i18n "wireframe.inspector.conditions.empty_hint"}}
          </p>
          <div class="wireframe-conditions-tree__seed-grid" role="menu">
            {{#each this.conditionTypes as |typeMeta|}}
              <DButton
                class="wireframe-conditions-tree__seed-chip"
                role="menuitem"
                @icon={{this.iconFor typeMeta.type}}
                @translatedLabel={{typeMeta.displayName}}
                @translatedTitle={{typeMeta.description}}
                @action={{fn this.seedFromEmpty typeMeta.type}}
              />
            {{/each}}
          </div>
        </div>
      {{else if this.rootLeaf}}
        {{! Legacy bare-leaf at the root. New trees seed as a single-item
            array, so this branch is for back-compat with older data. }}
        <div class="wireframe-conditions-tree__leaf-root">
          <ConditionRule
            @node={{this.rootLeaf}}
            @typeMeta={{this.metaFor this.rootLeaf}}
            @conditionTypes={{this.conditionTypes}}
            @onUpdate={{this.handleRootLeafUpdate}}
            @onChangeType={{this.handleRootLeafChangeType}}
            @onRemove={{this.handleRootLeafRemove}}
            @startExpanded={{true}}
          />
        </div>
      {{else if this.rootGroup}}
        <ConditionGroup
          @node={{this.rootGroup}}
          @path={{this.emptyPath}}
          @conditionTypes={{this.conditionTypes}}
          @onInsertLeaf={{this.handleInsertLeaf}}
          @onInsertGroup={{this.handleInsertGroup}}
          @onSetCombinator={{this.handleSetCombinator}}
          @onRemoveNode={{this.handleRemoveNode}}
          @onUpdateLeaf={{this.handleUpdateLeaf}}
          @newlyAddedPath={{this.newlyAddedPath}}
          @isRoot={{true}}
        />
      {{/if}}

      {{#unless this.isEmpty}}
        <div class="wireframe-conditions-tree__footer">
          <DButton
            class="btn-flat btn-small wireframe-conditions-tree__clear"
            @icon="trash-can"
            @label="wireframe.inspector.conditions.clear_all"
            @action={{this.clearAll}}
          />
        </div>
      {{/unless}}
    </div>
  </template>
}
