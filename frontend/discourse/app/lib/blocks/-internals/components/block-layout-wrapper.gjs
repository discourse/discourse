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
 * @property {string} name - The block's full registered name.
 * @property {string|null} namespace - The block's namespace prefix.
 * @property {boolean} isContainer - Whether this is a container block.
 * @property {string|null} [id] - Optional block ID for BEM modifiers and targeting.
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
 * @param {string} blockData.name - The block's full registered name.
 * @param {string} blockData.namespace - The block's namespace prefix.
 * @param {boolean} blockData.isContainer - Whether this is a container block.
 * @param {string|null} [blockData.id] - Optional block ID for BEM modifiers.
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
 * Component that wraps all blocks with a standard class structure.
 *
 * All blocks (both containers and non-containers) receive:
 * - `{outletName}__block` or `{outletName}__block-container` - Outlet-scoped class for styling
 * - `{outletName}__block--{id}` or `{outletName}__block-container--{id}` - BEM modifier when `id` is provided
 * - Custom classes from `@decoratorClassNames` (from the @block decorator)
 * - Custom classes from `@classNames` (from the layout entry)
 *
 * Block identity is available via data attributes:
 * - `data-block-name` - The block's full registered name
 * - `data-block-namespace` - The block's namespace (if present)
 * - `data-block-id` - The block's entry ID (if provided)
 *
 * @extends {Component<WrappedBlockLayoutSignature>}
 */
class WrappedBlockLayout extends Component {
  /**
   * Generates the appropriate CSS class based on block type and optional ID.
   * When an ID is provided, adds a BEM modifier class (e.g., `outlet__block--my-id`).
   *
   * @returns {string[]} An array of CSS class names.
   */
  get blockClassNames() {
    const safeOutlet = cssIdentifier(this.args.outletName);
    const baseClass = this.args.isContainer
      ? `${safeOutlet}__block-container`
      : `${safeOutlet}__block`;

    if (this.args.id) {
      return [baseClass, `${baseClass}--${this.args.id}`];
    }

    return [baseClass];
  }

  <template>
    <div
      class={{concatClass
        this.blockClassNames
        @decoratorClassNames
        @classNames
      }}
      data-block-id={{@id}}
      data-block-name={{@name}}
      data-block-namespace={{@namespace}}
    >
      <@Component />
    </div>
  </template>
}
