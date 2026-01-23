// @ts-check
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import { service } from "@ember/service";
import { withDebugGroup } from "discourse/lib/blocks/-internals/debug-hooks";
import { processBlockEntries } from "discourse/lib/blocks/-internals/entry-processing";
import { isOptionalMissing } from "discourse/lib/blocks/-internals/patterns";
import { tryResolveBlock } from "discourse/lib/blocks/-internals/registry/block";

/**
 * Internal container component that processes and renders block children.
 *
 * This component handles condition evaluation and component creation in a
 * tracked getter context. By evaluating conditions synchronously in
 * `processedChildren`, Ember's autotracking establishes dependencies on
 * services like `router` and `discovery`. Route changes trigger re-evaluation.
 *
 * If condition evaluation happened in the async promise chain (as it did
 * previously), service reads would not be tracked and route navigation
 * would not trigger re-evaluation.
 *
 * The component receives authorization-dependent functions (`createChildBlockFn`,
 * `isContainerBlockFn`) as props to maintain the authorization model in the
 * main block-outlet module.
 *
 * @private
 */
export default class BlockOutletRootContainer extends Component {
  @service blocks;

  /**
   * Cache for curried components, keyed by their stable block key.
   *
   * This cache prevents unnecessary component recreation during navigation.
   * Components are reused when their class and args haven't changed.
   *
   * Memory note: This cache is bounded, not unbounded:
   * - Keys use stable `__stableKey` values assigned once at registration time
   * - The same keys are reused on every render/navigation
   * - This cache instance is garbage collected when the owning component is destroyed
   *
   * @type {Map<string, {ComponentClass: typeof Component, args: Object, result: Object}>}
   */
  #componentCache = new Map();

  /**
   * Processes raw block entries and creates renderable child components.
   *
   * This getter is the key to reactive condition evaluation. By accessing
   * services like `router` and `discovery` during condition evaluation here
   * (synchronously in a tracked getter), Ember establishes tracking
   * dependencies. Route changes trigger this getter to re-run.
   *
   * @returns {Array<{Component: import("ember-curry-component").CurriedComponent, containerArgs: Object|undefined, key: string}>}
   */
  @cached
  get processedChildren() {
    const {
      rawChildren,
      showGhosts,
      isLoggingEnabled,
      outletName,
      outletArgs,
      createChildBlockFn,
      isContainerBlockFn,
    } = this.args;

    if (!rawChildren?.length) {
      return [];
    }

    const owner = getOwner(this);
    const baseHierarchy = outletName;

    // Step 1: Evaluate conditions - THIS IS NOW TRACKED!
    // When blocksService.evaluate() reads router.currentURL or discovery.category,
    // Ember establishes a dependency. Route changes trigger re-evaluation.
    const processedEntries = this.#preprocessEntries(
      rawChildren,
      outletArgs,
      this.blocks,
      showGhosts,
      isLoggingEnabled,
      baseHierarchy,
      isContainerBlockFn
    );

    // Step 2: Create components from processed entries
    // @ts-ignore - TS2322: ChildBlockResult type compatible with return type
    return processBlockEntries({
      entries: processedEntries,
      cache: this.#componentCache,
      owner,
      baseHierarchy,
      outletName,
      outletArgs,
      showGhosts,
      isLoggingEnabled,
      createChildBlockFn,
      isContainerBlockFn,
    });
  }

  /**
   * Pre-processes block entries to compute visibility for all blocks.
   *
   * This method evaluates conditions for all blocks in the tree and adds
   * visibility metadata to each entry:
   * - `__visible`: Whether the block should be rendered
   * - `__failureReason`: Why the block is hidden (debug mode only)
   *
   * Container blocks have an implicit condition: they must have at least
   * one visible child. This is evaluated bottom-up (children first).
   *
   * @param {Array<Object>} entries - Array of block entries to process.
   * @param {Object} outletArgs - Outlet arguments for condition evaluation.
   * @param {Object} blocksService - Blocks service for condition evaluation.
   * @param {boolean} showGhosts - If true, keep all blocks for ghost rendering.
   * @param {boolean} isLoggingEnabled - If true, log condition evaluation.
   * @param {string} baseHierarchy - Base hierarchy path for logging.
   * @param {Function} isContainerBlockFn - Function to check if a block is a container.
   * @returns {Array<Object>} Processed entries with visibility metadata.
   */
  #preprocessEntries(
    entries,
    outletArgs,
    blocksService,
    showGhosts,
    isLoggingEnabled,
    baseHierarchy,
    isContainerBlockFn
  ) {
    const result = [];

    for (const entry of entries) {
      // Shallow clone to add visibility metadata without mutating the original
      // layout entry. The layout is immutable after registration, so we create
      // a copy to attach __visible and __failureReason properties.
      const entryClone = { ...entry };

      // Resolve block reference
      const resolvedBlock = tryResolveBlock(entryClone.block);

      // Skip unresolved blocks (optional missing or pending factory resolution)
      if (!resolvedBlock || isOptionalMissing(resolvedBlock)) {
        // Keep the entry for ghost handling in the main loop
        if (showGhosts || isOptionalMissing(resolvedBlock)) {
          result.push(entryClone);
        }
        continue;
      }

      const blockClass =
        /** @type {import("discourse/lib/blocks/-internals/registry/block").BlockClass} */ (
          resolvedBlock
        );
      const blockName = blockClass.blockName || "unknown";
      const isContainer = isContainerBlockFn(blockClass);

      // Evaluate this block's own conditions.
      // The withDebugGroup wrapper ensures START_GROUP/END_GROUP are always paired.
      // This is the key reactive line - blocksService.evaluate() reads from router/discovery
      // services, and since we're in a tracked getter, Ember tracks these reads.
      const conditionsPassed = entryClone.conditions
        ? withDebugGroup(blockName, baseHierarchy, isLoggingEnabled, () =>
            blocksService.evaluate(entryClone.conditions, {
              debug: isLoggingEnabled,
              outletArgs,
            })
          )
        : true;

      // For containers: recursively process children first (bottom-up evaluation)
      // This determines which children are visible before we check if container has any
      let hasVisibleChildren = true; // Non-containers always "have" visible children
      if (isContainer && entryClone.children?.length) {
        // Recursively preprocess children - this computes their visibility
        const processedChildren = this.#preprocessEntries(
          entryClone.children,
          outletArgs,
          blocksService,
          showGhosts,
          isLoggingEnabled,
          `${baseHierarchy}/${blockName}`,
          isContainerBlockFn
        );

        hasVisibleChildren = processedChildren.some((child) => child.__visible);

        // Update the cloned entry's children with the processed result
        entryClone.children = processedChildren;
      }

      // Final visibility: own conditions must pass AND (not container OR has visible children)
      // This implements the implicit "container must have visible children" condition
      const visible = conditionsPassed && hasVisibleChildren;
      entryClone.__visible = visible;

      // In debug mode, record why the block is hidden for the ghost tooltip
      if (showGhosts && !visible) {
        entryClone.__failureReason = !conditionsPassed
          ? "condition-failed"
          : "no-visible-children";
      }

      // In production mode, filter out invisible blocks
      // In debug mode, keep all blocks for ghost rendering
      if (visible || showGhosts) {
        result.push(entryClone);
      }
    }

    return result;
  }

  <template>
    <div class={{@outletName}}>
      <div class="{{@outletName}}__container">
        <div class="{{@outletName}}__layout">
          {{#each this.processedChildren key="key" as |child|}}
            <child.Component />
          {{/each}}
        </div>
      </div>
    </div>
  </template>
}
