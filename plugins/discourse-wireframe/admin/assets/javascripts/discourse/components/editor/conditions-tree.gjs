// @ts-check
import Component from "@glimmer/component";
import { cached, tracked } from "@glimmer/tracking";
import { fn } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";
import { iconForConditionType } from "../../lib/condition-icons";
import { classifyNode } from "../../lib/condition-tree";
import {
  insertGroup,
  insertLeaf,
  isGroup,
  isLeaf,
  removeAt,
  setCombinator,
  updateLeaf,
} from "../../lib/condition-tree-ops";
import ConditionGroup from "./condition-group";
import ConditionRule from "./condition-rule";

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
  @service wireframeEntryConfig;
  @service wireframeSelection;
  @service blocks;

  /**
   * Path of the most-recently-inserted node. `<ConditionGroup>` reads
   * this to start the matching child in the expanded state on its
   * first render — so authors immediately see the editor without
   * having to click the row again.
   *
   * Set by `handleInsertLeaf` / `seedFromEmpty`; cleared on every
   * non-insert mutation so stale paths don't keep re-expanding rows.
   *
   * @type {Array<string|number>|null}
   */
  @tracked newlyAddedPath = null;
  emptyPath = [];
  iconFor = (typeId) => iconForConditionType(typeId);
  metaFor = (leaf) => {
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
   * @returns {Object|null}
   */
  @cached
  get tree() {
    return this.wireframeSelection.selectedBlockConditions;
  }

  /**
   * Registered condition types from the blocks service. Drives the
   * "Add rule" picker.
   *
   * @returns {Array<Object>}
   */
  @cached
  get conditionTypes() {
    return this.blocks.listConditionTypes();
  }

  /**
   * `true` when the tree contains no rules — drives the empty-state
   * placeholder.
   *
   * @returns {boolean}
   */
  get isEmpty() {
    return classifyNode(this.tree) === "empty";
  }

  /**
   * `true` when the root node is itself a leaf rule (not wrapped in a
   * group). The UI renders a single-rule shorthand for this case.
   *
   * @returns {boolean}
   */
  get rootIsLeaf() {
    return isLeaf(this.tree);
  }

  /**
   * `true` when the root node is a combinator group (AND / OR / NOT).
   *
   * @returns {boolean}
   */
  get rootIsGroup() {
    return isGroup(this.tree);
  }

  /**
   * Commits a new tree to the editor service. Conditions are
   * structural, so the change lands on the undo stack alongside drag
   * / insert / remove mutations.
   *
   * @param {*} next
   */
  commit(next) {
    this.wireframeEntryConfig.updateSelectedConditions(next ?? null);
  }

  @action
  handleInsertLeaf(groupPath, typeId) {
    this.#markNewlyAddedFor(groupPath);
    this.commit(insertLeaf(this.tree ?? [], groupPath, typeId));
  }

  @action
  handleInsertGroup(groupPath, combinator) {
    this.newlyAddedPath = null;
    this.commit(insertGroup(this.tree ?? [], groupPath, combinator));
  }

  @action
  handleSetCombinator(path, newCombinator) {
    this.newlyAddedPath = null;
    this.commit(setCombinator(this.tree, path, newCombinator));
  }

  @action
  handleRemoveNode(path) {
    this.newlyAddedPath = null;
    this.commit(removeAt(this.tree, path));
  }

  @action
  handleUpdateLeaf(path, nextLeaf) {
    this.newlyAddedPath = null;
    this.commit(updateLeaf(this.tree, path, nextLeaf));
  }

  @action
  handleRootLeafUpdate(nextLeaf) {
    this.newlyAddedPath = null;
    this.commit(nextLeaf);
  }

  @action
  handleRootLeafChangeType(typeId) {
    this.newlyAddedPath = null;
    this.commit({ type: typeId });
  }

  @action
  handleRootLeafRemove() {
    this.newlyAddedPath = null;
    this.commit(null);
  }

  @action
  seedFromEmpty(typeId) {
    // Seed in the array (AND) form so the freshly-seeded tree carries
    // a group header — the user can immediately add more rules from
    // the same surface. Mark the new rule for auto-expansion.
    this.newlyAddedPath = [0];
    this.commit([{ type: typeId }]);
  }

  @action
  clearAll() {
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
   */
  #markNewlyAddedFor(groupPath) {
    const tree = this.tree ?? [];
    const group = groupPath.length === 0 ? tree : this.#readAt(tree, groupPath);
    if (!group) {
      this.newlyAddedPath = null;
      return;
    }
    const kind = classifyNode(group);
    if (kind === "and") {
      this.newlyAddedPath = [...groupPath, group.length];
      return;
    }
    if (kind === "or") {
      this.newlyAddedPath = [...groupPath, "any", group.any.length];
      return;
    }
    if (kind === "not") {
      if (Array.isArray(group.not)) {
        this.newlyAddedPath = [...groupPath, "not", group.not.length];
        return;
      }
      // Empty NOT case never happens (newEmptyGroup seeds with a leaf)
      // but if it did, promotion would put the new leaf at index 1.
      this.newlyAddedPath = [...groupPath, "not", 1];
      return;
    }
    this.newlyAddedPath = null;
  }

  #readAt(tree, path) {
    let node = tree;
    for (const seg of path) {
      if (node == null) {
        return null;
      }
      if (seg === "any") {
        node = node.any;
      } else if (seg === "not") {
        node = node.not;
      } else {
        node = node[seg];
      }
    }
    return node;
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
      {{else if this.rootIsLeaf}}
        {{! Legacy bare-leaf at the root. New trees seed as `[leaf]`
            so this branch is for back-compat with older data. }}
        <div class="wireframe-conditions-tree__leaf-root">
          <ConditionRule
            @node={{this.tree}}
            @typeMeta={{this.metaFor this.tree}}
            @conditionTypes={{this.conditionTypes}}
            @onUpdate={{this.handleRootLeafUpdate}}
            @onChangeType={{this.handleRootLeafChangeType}}
            @onRemove={{this.handleRootLeafRemove}}
            @startExpanded={{true}}
          />
        </div>
      {{else if this.rootIsGroup}}
        <ConditionGroup
          @node={{this.tree}}
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
