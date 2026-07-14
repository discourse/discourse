/**
 * Block layout wrapper for blocks.
 *
 * This module provides standard wrapper components for both leaf blocks
 * (non-container) and container blocks. All blocks rendered through
 * `BlockOutlet` use these wrappers to ensure consistent BEM-style class
 * naming and layout structure.
 */
import Component from "@glimmer/component";
import { cached } from "@glimmer/tracking";
import { getOwner } from "@ember/owner";
import type { TrackedAsyncData } from "ember-async-data";
import curryComponent from "ember-curry-component";
import cssIdentifier from "discourse/helpers/css-identifier";
import BlockData from "discourse/lib/blocks/-internals/components/block-data";
import { getBlockData } from "discourse/lib/blocks/-internals/data-coordinator";
import type { BlockComponent } from "discourse/lib/blocks/-internals/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

/**
 * The application owner, used for currying components and resolving data.
 *
 * Referenced through an inline import type (rather than `import type Owner`)
 * because `getOwner` is already imported from the same module as a value, and
 * the value and default-type import cannot be combined into a single statement.
 */
type Owner = import("@ember/owner").default;

/**
 * The reserved-space shape for a loading skeleton, produced by a block's
 * optional `skeleton(args)` hint and forwarded to the default skeleton so it
 * can reserve roughly the space the resolved content will occupy.
 */
interface BlockSkeletonShape {
  variant?: string;
  count?: number;
  width?: string;
  height?: string;
}

/**
 * A block's declared data dependency, recorded by the `@block` decorator's
 * `data` option. `request` maps the block's args to a serializable descriptor
 * (or `null` when no async data is needed for the current args); `resolve`
 * turns that descriptor into render-ready data; the optional `hydrate` adapts a
 * server-preloaded payload; and the optional `skeleton` shapes the loading
 * placeholder.
 */
interface BlockDataMeta {
  request: (args?: Record<string, unknown> | null) => unknown;
  resolve: (
    descriptor: unknown,
    options: { owner?: Owner; signal?: AbortSignal }
  ) => unknown;
  hydrate?: (raw: unknown, options: { owner?: Owner }) => unknown;
  skeleton?: (args?: Record<string, unknown> | null) => BlockSkeletonShape;
}

interface WrappedBlockLayoutArgs {
  // The outlet name for class generation.
  outletName: string;
  // The block's full registered name.
  name?: string;
  // The block's namespace prefix.
  namespace?: string | null;
  // Whether this is a container block.
  isContainer: boolean;
  // Optional block ID for BEM modifiers and targeting.
  id?: string;
  // The curried block component to render.
  Component: BlockComponent;
  // Additional CSS classes from the layout entry.
  classNames?: string;
  // Extra CSS classes from the @block decorator.
  decoratorClassNames?: string | null;
  // Optional inline style applied to the wrapper's outer element. Parent
  // containers pass this at the invocation site when they need to position
  // their children (e.g. CSS Grid placement, per-child flexbox overrides). The
  // wrapper itself is layout-agnostic and just applies whatever the parent
  // computes.
  style?: string;
  // The block's declared data dependency, present when the block declares a
  // data option, otherwise null. When present the wrapper resolves it and
  // hands the block a bound data-region boundary as the Data argument.
  dataMeta?: BlockDataMeta | null;
  // The block's reactive args object, used to derive the request descriptor.
  // Reading named keys keeps the lookup reactive.
  dataArgs?: Record<string, unknown> | null;
}

interface WrappedBlockLayoutSignature {
  Args: WrappedBlockLayoutArgs;
}

/**
 * Wraps a block in a standard layout wrapper with BEM-style classes.
 */
export function wrapBlockLayout(
  blockData: WrappedBlockLayoutArgs,
  owner: Owner
): BlockComponent {
  return curryComponent(WrappedBlockLayout, blockData, owner);
}

/**
 * Component that wraps all blocks with a standard class structure.
 *
 * All blocks (both containers and non-containers) receive:
 * - `{outletName}__block` or `{outletName}__block-container` - Outlet-scoped class for styling
 * - `{outletName}__block--{id}` or `{outletName}__block-container--{id}` - BEM modifier when `id` is provided
 * - Custom classes from `@decoratorClassNames` (from the `@block` decorator)
 * - Custom classes from `@classNames` (from the layout entry)
 *
 * Block identity is available via data attributes:
 * - `data-block-name` - The block's full registered name
 * - `data-block-namespace` - The block's namespace (if present)
 * - `data-block-id` - The block's entry ID (if provided)
 */
class WrappedBlockLayout extends Component<WrappedBlockLayoutSignature> {
  /**
   * Generates the appropriate CSS class based on block type and optional ID.
   * When an ID is provided, adds a BEM modifier class (e.g., `outlet__block--my-id`).
   */
  get blockClassNames(): string[] {
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
   * arg edits do not. This runs at render, after the outlet's synchronous
   * processing, so it never affects that getter.
   */
  @cached
  get blockData(): TrackedAsyncData<unknown> | null {
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
   * does not supply its own loading block. Defaults to an empty shape so the
   * skeleton falls back to its own defaults.
   */
  get skeletonShape(): BlockSkeletonShape {
    const skeleton = this.args.dataMeta?.skeleton;
    return skeleton ? skeleton(this.args.dataArgs) : {};
  }

  /**
   * The data-region boundary handed to the block as the `Data` argument, or
   * `undefined` when the block declares no `data`. It is `BlockData` curried
   * with this block's live data state and reserved-space shape, so the block
   * places the boundary around its data region without wiring the state itself.
   * Currying here (rather than in the block) keeps the state private and the
   * block a pure renderer of its own surrounding markup plus the yielded value.
   */
  @cached
  get dataComponent(): BlockComponent | undefined {
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
      {{! A block that declares data receives Data, a bound boundary it places
          around its data region so its surrounding markup stays outside and
          visible while loading. Blocks without data receive an undefined Data
          and just render. The generic block component type does not model the
          Data arg, which the framework supplies dynamically. }}
      {{! @glint-expect-error - a data-declaring block receives Data dynamically from the framework curry }}
      <@Component @Data={{this.dataComponent}} />
    </div>
  </template>
}
