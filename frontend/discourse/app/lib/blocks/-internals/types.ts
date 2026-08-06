import type { ComponentLike } from "@glint/template";

/**
 * A block component class decorated with `@block`. Block metadata is stored in
 * an internal WeakMap and read via `getBlockMetadata()`.
 *
 * Glimmer's `Component` is generic and invariant over its `Signature`, so
 * neither `typeof Component` nor `Component<unknown>` accepts a concrete
 * subclass like `class Foo extends Component<FooSignature>`. Since a block class
 * is only ever stored, compared, and curried as an opaque token here — its
 * component-ness is enforced at runtime by the `@block` decorator's
 * `instanceof Component` check — a permissive construct signature is the
 * idiomatic way to accept "any block component class".
 */
export type BlockClass = abstract new (...args: unknown[]) => object;

/**
 * A factory that lazily resolves to a block class (or a module whose default
 * export is one), used for code-split block registration.
 */
export type BlockFactory = () => Promise<BlockClass | { default: BlockClass }>;

/** A registry entry: either a resolved block class or a lazy factory. */
export type BlockRegistryEntry = BlockClass | BlockFactory;

/**
 * A curried, render-ready block component. Curried components carry no
 * statically known args, so this is intentionally a permissive `ComponentLike`.
 */
export type BlockComponent = ComponentLike;

/**
 * A block entry after preprocessing, carrying the visibility/keying metadata
 * the render pipeline assigns (the `__`-prefixed fields).
 */
export interface BlockEntry {
  block: string | BlockClass;
  args?: Record<string, unknown>;
  containerArgs?: Record<string, unknown>;
  children?: BlockEntry[];
  conditions?: object | object[];
  classNames?: string;
  id?: string;

  // Whether the block passed condition evaluation.
  __visible: boolean;

  // Stable key assigned at registration time, preserved across renders.
  __stableKey: number;

  // Failure metadata, populated in debug mode only.
  __failureType?: string;
  __failureReason?: string;
}

/**
 * A renderable child produced by the block pipeline: the curried component, any
 * `containerArgs` destined for the parent's `childArgs` schema, and a stable key
 * for list rendering.
 */
export interface ChildBlockResult {
  Component: BlockComponent;
  containerArgs?: Record<string, unknown>;
  key: string;

  // True for a ghost placeholder rendered in debug mode.
  isGhost?: boolean;

  // Returns a ghost version of this child with the given reason (debug mode),
  // or null when debug mode is disabled. Ghost children return themselves.
  asGhost?: (reason: string) => ChildBlockResult | null;
}
