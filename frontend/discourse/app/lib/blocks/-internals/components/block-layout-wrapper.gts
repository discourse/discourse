/**
 * Block layout wrapper for blocks.
 *
 * This module provides standard wrapper components for both leaf blocks
 * (non-container) and container blocks. All blocks rendered through
 * `BlockOutlet` use these wrappers to ensure consistent BEM-style class
 * naming and layout structure.
 */
import Component from "@glimmer/component";
import type Owner from "@ember/owner";
import curryComponent from "ember-curry-component";
import cssIdentifier from "discourse/helpers/css-identifier";
import type { BlockComponent } from "discourse/lib/blocks/-internals/types";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";

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

  <template>
    <div
      class={{dConcatClass
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
