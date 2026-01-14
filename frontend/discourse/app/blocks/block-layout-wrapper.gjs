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
import { concat } from "@ember/helper";
import curryComponent from "ember-curry-component";
import concatClass from "discourse/helpers/concat-class";
import cssName from "discourse/helpers/css-name";

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
      (concat (cssName @outletName) "__block")
      (concat "block-" (cssName @name))
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;

/**
 * Wraps a container block in a standard layout wrapper.
 * This provides consistent styling and class naming for container blocks.
 *
 * @param {Object} blockData - Block rendering data.
 * @param {string} blockData.name - The block's registered name.
 * @param {string} [blockData.containerClassNames] - Extra CSS classes from decorator (resolved).
 * @param {string} [blockData.classNames] - Additional CSS classes from layout entry.
 * @param {import("ember-curry-component").CurriedComponent} blockData.Component - The curried block component.
 * @param {import("@ember/owner").default} owner - The application owner for currying.
 * @returns {import("ember-curry-component").CurriedComponent} The wrapped component.
 */
export function wrapContainerBlockLayout(blockData, owner) {
  return curryComponent(WrappedContainerBlockLayout, blockData, owner);
}

/**
 * Template-only component that wraps container blocks.
 *
 * Generates BEM-style class names:
 * - `block__{name}` - Identifies the container block type
 * - `{outletName}__{name}` - Identifies this as a container within the outlet
 * - Custom containerClassNames from decorator
 * - Custom classNames from layout entry configuration
 */
const WrappedContainerBlockLayout = <template>
  <div
    class={{concatClass
      (concat "block__" (cssName @name))
      (concat (cssName @outletName) "__" (cssName @name))
      @containerClassNames
      @classNames
    }}
  >
    <@Component />
  </div>
</template>;
