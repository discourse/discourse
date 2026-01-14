/**
 * Block layout wrapper for blocks.
 *
 * This module provides standard wrapper components for both leaf blocks
 * (non-container) and container blocks. All blocks rendered through
 * `BlockOutlet` use these wrappers to ensure consistent BEM-style class
 * naming and layout structure.
 *
 * @module discourse/blocks/block-layout-wrapper
 */
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import cssName from "discourse/helpers/css-name";

/**
 * Wraps a block in a standard layout wrapper with BEM-style classes.
 *
 * @param {Object} blockData - Block rendering data.
 * @param {string} blockData.name - The block's registered name.
 * @param {boolean} blockData.isContainer - Whether this is a container block.
 * @param {string} [blockData.containerClassNames] - Extra CSS classes from decorator (container blocks only).
 * @param {string} [blockData.classNames] - Additional CSS classes from layout entry.
 * @param {import("ember-curry-component").CurriedComponent} blockData.Component - The curried block component.
 * @param {import("@ember/owner").default} owner - The application owner for currying.
 * @returns {import("ember-curry-component").CurriedComponent} The wrapped component.
 */
export function wrapBlockLayout(blockData, owner) {
  return curryComponent(WrappedBlockLayout, blockData, owner);
}

/**
 * Generates the appropriate CSS class based on block type.
 *
 * @param {string} outletName - The outlet name.
 * @param {string} name - The block name.
 * @param {boolean} isContainer - Whether this is a container block.
 * @returns {string} The generated CSS class string.
 */
function blockClass(outletName, name, isContainer) {
  const safeName = cssName(name);
  const safeOutlet = cssName(outletName);

  if (isContainer) {
    return [`block__${safeName}`, `${safeOutlet}__${safeName}`];
  }

  return [`${safeOutlet}__block`, `block-${safeName}`];
}

/**
 * Template-only component that wraps all blocks.
 *
 * Generates BEM-style class names based on block type:
 *
 * For non-container blocks:
 * - `{outletName}__block` - Identifies this as a block within the outlet
 * - `block-{name}` - Identifies the specific block type
 *
 * For container blocks:
 * - `block__{name}` - Identifies the container block type
 * - `{outletName}__{name}` - Identifies this as a container within the outlet
 * - Custom containerClassNames from decorator
 *
 * Both types include custom classNames from layout entry configuration.
 */
const WrappedBlockLayout = <template>
  <div
    class={{concatClass
      (blockClass @outletName @name @isContainer)
      @containerClassNames
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;
