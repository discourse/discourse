import { DEBUG_CALLBACK, debugHooks } from "discourse/lib/blocks/debug-hooks";
import { OPTIONAL_MISSING } from "discourse/lib/blocks/patterns";

/**
 * Handles an optional missing block by logging and optionally creating a ghost.
 *
 * When a block reference ends with `?` but the block is not registered, this
 * function handles the logging and ghost component creation.
 *
 * @param {Object} options - Options for handling the missing block.
 * @param {string} options.blockName - The name of the missing block.
 * @param {Object} options.blockConfig - The block configuration.
 * @param {string} options.hierarchy - The hierarchy path for logging.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is enabled.
 * @param {boolean} options.showGhosts - Whether to show ghost components.
 * @returns {{Component: import("ember-curry-component").CurriedComponent}|null}
 *   Ghost component data if showGhosts is true, null otherwise.
 */
export function handleOptionalMissingBlock({
  blockName,
  blockConfig,
  hierarchy,
  isLoggingEnabled,
  showGhosts,
}) {
  // Log if debug logging is enabled
  if (isLoggingEnabled) {
    debugHooks.getCallback(DEBUG_CALLBACK.OPTIONAL_MISSING_LOG)?.(
      blockName,
      hierarchy
    );
  }

  // Show ghost if visual overlay is enabled
  if (showGhosts) {
    const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)(
      {
        name: blockName,
        Component: null,
        args: blockConfig.args,
        conditions: blockConfig.conditions,
        conditionsPassed: false,
        optionalMissing: true,
      },
      { outletName: hierarchy }
    );
    return ghostData?.Component ? ghostData : null;
  }

  return null;
}

/**
 * Checks if a resolved block is an optional missing block marker.
 *
 * @param {*} resolvedBlock - The result from resolveBlockSync.
 * @returns {boolean} True if the block is an optional missing marker.
 */
export function isOptionalMissing(resolvedBlock) {
  return resolvedBlock?.optionalMissing === OPTIONAL_MISSING;
}

/**
 * Builds a container path for nested containers.
 *
 * Maintains a count map to ensure unique indices for containers of the same type.
 * For example, if there are two "group" containers, they get paths like:
 * - `baseHierarchy/group[0]`
 * - `baseHierarchy/group[1]`
 *
 * @param {string} blockName - The block name.
 * @param {string} baseHierarchy - The base hierarchy path.
 * @param {Map<string, number>} containerCounts - Map tracking container counts.
 * @returns {string} The full container path.
 */
export function buildContainerPath(blockName, baseHierarchy, containerCounts) {
  const count = containerCounts.get(blockName) ?? 0;
  containerCounts.set(blockName, count + 1);
  return `${baseHierarchy}/${blockName}[${count}]`;
}

/**
 * Creates a ghost component for an invisible block.
 *
 * Ghost components are shown in debug mode to visualize blocks that failed
 * their conditions or have no visible children.
 *
 * @param {Object} options - Options for creating the ghost.
 * @param {string} options.blockName - The block name.
 * @param {Object} options.blockConfig - The block configuration.
 * @param {string} options.hierarchy - The hierarchy path for display.
 * @param {string|undefined} options.containerPath - Container path for child hierarchies.
 * @param {boolean} options.isContainer - Whether this block is a container.
 * @param {import("@ember/owner").default} options.owner - The application owner.
 * @param {Object} options.outletArgs - Outlet arguments.
 * @param {boolean} options.isLoggingEnabled - Whether debug logging is enabled.
 * @param {Function} options.resolveBlockFn - Function to resolve block references.
 * @returns {{Component: import("ember-curry-component").CurriedComponent}|null}
 *   Ghost component data if successful, null otherwise.
 */
export function createGhostBlock({
  blockName,
  blockConfig,
  hierarchy,
  containerPath,
  isContainer,
  owner,
  outletArgs,
  isLoggingEnabled,
  resolveBlockFn,
}) {
  // For container blocks with children that failed due to no visible children,
  // recursively create ghost children so they appear nested in the debug overlay.
  let ghostChildren = null;
  if (
    isContainer &&
    blockConfig.children?.length &&
    blockConfig.__failureReason === "no-visible-children"
  ) {
    ghostChildren = debugHooks.getCallback(
      DEBUG_CALLBACK.GHOST_CHILDREN_CREATOR
    )?.(
      blockConfig.children,
      owner,
      containerPath,
      outletArgs,
      isLoggingEnabled,
      resolveBlockFn
    );
  }

  const ghostData = debugHooks.getCallback(DEBUG_CALLBACK.BLOCK_DEBUG)(
    {
      name: blockName,
      Component: null,
      args: blockConfig.args,
      containerArgs: blockConfig.containerArgs,
      conditions: blockConfig.conditions,
      conditionsPassed: false,
      failureReason: blockConfig.__failureReason,
      children: ghostChildren,
    },
    { outletName: hierarchy }
  );

  return ghostData?.Component ? ghostData : null;
}
