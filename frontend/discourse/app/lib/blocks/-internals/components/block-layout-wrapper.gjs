// @ts-check
/**
 * Block layout wrapper for blocks.
 *
 * This module provides standard wrapper components for both leaf blocks
 * (non-container) and container blocks. All blocks rendered through
 * `BlockOutlet` use these wrappers to ensure consistent BEM-style class
 * naming and layout structure.
 *
 * @module discourse/lib/blocks/-internals/components/block-layout-wrapper
 */
import Component from "@glimmer/component";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import cssIdentifier from "discourse/helpers/css-identifier";

/**
 * @typedef {import("ember-curry-component").CurriedComponent} CurriedComponent
 */

/**
 * @typedef {Object} WrappedBlockLayoutArgs
 * @property {string} outletName - The outlet name for class generation.
 * @property {string} name - The block's registered name.
 * @property {boolean} isContainer - Whether this is a container block.
 * @property {CurriedComponent} Component - The curried block component to render.
 * @property {string} [classNames] - Additional CSS classes from layout entry.
 * @property {string} [decoratorClassNames] - Extra CSS classes from the @block decorator.
 */

/**
 * @typedef {Object} WrappedBlockLayoutSignature
 * @property {WrappedBlockLayoutArgs} Args
 */

/**
 * Wraps a block in a standard layout wrapper with BEM-style classes.
 *
 * @param {Object} blockData - Block rendering data.
 * @param {string} blockData.outletName - The outlet name for class generation.
 * @param {string} blockData.name - The block's registered name.
 * @param {boolean} blockData.isContainer - Whether this is a container block.
 * @param {CurriedComponent} blockData.Component - The curried block component.
 * @param {string} [blockData.classNames] - Additional CSS classes from layout entry.
 * @param {string} [blockData.decoratorClassNames] - Extra CSS classes from the @block decorator.
 * @param {import("@ember/owner").default} owner - The application owner for currying.
 * @returns {CurriedComponent} The wrapped component.
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
 * @returns {string[]} An array of CSS class names.
 */
function blockClass(outletName, name, isContainer) {
  const safeName = cssIdentifier(name);
  const safeOutlet = cssIdentifier(outletName);

  if (isContainer) {
    return [`block__${safeName}`, `${safeOutlet}__${safeName}`];
  }

  return [`${safeOutlet}__block`, `block-${safeName}`];
}

/**
 * Component that wraps all blocks with BEM-style classes.
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
 *
 * Both types can include custom decoratorClassNames from the @block decorator
 * and custom classNames from layout entry configuration.
 *
 * @extends {Component<WrappedBlockLayoutSignature>}
 */
// eslint-disable-next-line ember/no-empty-glimmer-component-classes -- Class required for TypeScript signature
class WrappedBlockLayout extends Component {
  <template>
    <div
      class={{concatClass
        (blockClass @outletName @name @isContainer)
        @decoratorClassNames
        @classNames
      }}
    >
      <@Component />
    </div>
  </template>
}
