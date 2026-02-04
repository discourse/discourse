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
import { concat } from "@ember/helper";
import curryComponent from "ember-curry-component";
import booleanString from "discourse/helpers/boolean-string";
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
 * - `{outletName}__block` - Outlet-scoped class for styling
 * - Custom classes from `@decoratorClassNames` (from the @block decorator)
 * - Custom classes from `@classNames` (from the layout entry)
 *
 * Block identity is available via data attributes:
 * - `data-block-name` - The block's full registered name
 * - `data-block-namespace` - The block's namespace (if present)
 * - `data-block-container` - "true" for container blocks (omitted for non-containers)
 *
 * @extends {Component<WrappedBlockLayoutSignature>}
 */
// eslint-disable-next-line ember/no-empty-glimmer-component-classes -- Class required for TypeScript signature
class WrappedBlockLayout extends Component {
  <template>
    <div
      class={{concatClass
        (concat (cssIdentifier @outletName) "__block")
        @decoratorClassNames
        @classNames
      }}
      data-block-name={{@name}}
      data-block-namespace={{@namespace}}
      data-block-container={{booleanString @isContainer omitFalse=true}}
    >
      <@Component />
    </div>
  </template>
}
