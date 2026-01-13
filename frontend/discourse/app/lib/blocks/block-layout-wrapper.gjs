/**
 * Block layout wrapper for non-container blocks.
 *
 * This module provides the standard wrapper component for leaf blocks
 * (blocks that don't contain children). All leaf blocks rendered through
 * `BlockOutlet` use this wrapper to ensure consistent BEM-style class
 * naming and layout structure.
 *
 * @module discourse/lib/blocks/block-layout-wrapper
 */
import { concat } from "@ember/helper";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import dasherize from "discourse/helpers/dasherize";

/**
 * Wraps a non-container block in a standard layout wrapper.
 * This provides consistent styling and class naming for all blocks.
 *
 * @param {Object} blockData - Block rendering data.
 * @param {string} blockData.name - The block's registered name.
 * @param {string} [blockData.classNames] - Additional CSS classes.
 * @param {import("ember-curry-component").CurriedComponent} blockData.Component - The curried block component.
 * @param {import("@ember/owner").default} owner - The application owner for currying.
 * @returns {import("ember-curry-component").CurriedComponent} The wrapped component.
 */
export function wrapBlockLayout(blockData, owner) {
  return curryComponent(WrappedBlockLayout, blockData, owner);
}

/**
 * Template-only component that wraps non-container blocks.
 *
 * Generates BEM-style class names:
 * - `{outletName}__block` - Identifies this as a block within the outlet
 * - `block-{name}` - Identifies the specific block type
 * - Custom classNames from configuration
 */
const WrappedBlockLayout = <template>
  <div
    class={{concatClass
      (concat (dasherize @outletName) "__block")
      (concat "block-" (dasherize @name))
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;
