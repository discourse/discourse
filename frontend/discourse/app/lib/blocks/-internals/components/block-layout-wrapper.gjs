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
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import curryComponent from "ember-curry-component";
import cssIdentifier from "discourse/helpers/css-identifier";
/** @type {import("discourse/lib/blocks/-internals/components/block-data.gjs")} */
import BlockData from "discourse/lib/blocks/-internals/components/block-data";
import { getBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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
 * @property {string} [decoratorClassNames] - Extra CSS classes from the `@block` decorator.
 * @property {string} [style] - Optional inline style applied to the wrapper's
 *   outer `<div>`. Parent containers pass this in at the invocation site when
 *   they need to position their children — e.g. CSS Grid placement, flexbox
 *   per-child overrides. The wrapper itself is layout-agnostic; it just
 *   applies whatever style the parent computes.
 * @property {Object|null} [dataMeta] - The block's declared data dependency
 *   ({ request, resolve, hydrate?, skeleton? }) when it has one, else null.
 *   Present means the block receives a bound `BlockData` boundary as `@Data`.
 * @property {Object|null} [dataArgs] - The block's reactive args object, used to
 *   derive the request descriptor. Reading named keys keeps the lookup reactive.
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
 * @param {string} [blockData.decoratorClassNames] - Extra CSS classes from the `@block` decorator.
 * @param {Object|null} [blockData.dataMeta] - The block's declared data dependency, or null.
 * @param {Object|null} [blockData.dataArgs] - The block's reactive args object for descriptor derivation.
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

  /**
   * The block's coordinated data, or `null` when the block declares no `data`
   * (or its `request` returns null for the current args, meaning no async data
   * is needed). Deriving the descriptor here — by reading the named args the
   * `request` touches — keeps the lookup reactive: a change to an arg the
   * descriptor depends on yields a new key and a fresh result, while unrelated
   * arg edits don't. This runs at render, after the outlet's synchronous
   * processing, so it never affects that getter.
   *
   * @returns {import("ember-async-data").TrackedAsyncData<unknown>|null}
   */
  @cached
  get blockData() {
    const dataMeta = this.args.dataMeta;
    if (!dataMeta) {
      return null;
    }

    const descriptor = dataMeta.request(this.args.dataArgs);

    return getBlockData({
      scope: this.args.outletName,
      blockName: this.args.name,
      descriptor,
      dataMeta,
      owner: getOwner(this),
    });
  }

  /**
   * The reserved-space shape for the loading skeleton, from the block's
   * optional `skeleton(args)` hint, used as the default skeleton when the block
   * doesn't supply its own `:loading`. Defaults to an empty shape so the
   * skeleton falls back to its own defaults.
   *
   * @returns {Object}
   */
  get skeletonShape() {
    const skeleton = this.args.dataMeta?.skeleton;
    return skeleton ? skeleton(this.args.dataArgs) : {};
  }

  /**
   * The data-region boundary handed to the block as `@Data`, or `undefined`
   * when the block declares no `data`. It is `BlockData` curried with this
   * block's live data state and reserved-space shape, so the block places the
   * boundary around its data region without wiring the state itself. Currying
   * here (rather than in the block) keeps the state private and the block a
   * pure renderer of its chrome plus the yielded value.
   *
   * @returns {import("ember-curry-component").CurriedComponent|undefined}
   */
  @cached
  get dataComponent() {
    if (!this.blockData) {
      return undefined;
    }

    return curryComponent(
      BlockData,
      { state: this.blockData, skeletonShape: this.skeletonShape },
      getOwner(this)
    );
  }

  <template>
    <div
      class={{dConcatClass
        this.blockClassNames
        @decoratorClassNames
        @classNames
      }}
      style={{@style}}
      data-block-id={{@id}}
      data-block-name={{@name}}
      data-block-namespace={{@namespace}}
    >
      {{! A block that declares data receives `@Data` — a bound boundary it
          places around its data region (chrome stays outside, visible while
          loading). Blocks without data get `@Data` undefined and just render. }}
      <@Component @Data={{this.dataComponent}} />
    </div>
  </template>
}
