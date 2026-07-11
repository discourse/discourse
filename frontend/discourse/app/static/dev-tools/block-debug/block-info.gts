import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { type ComponentLike } from "@glint/template";
import DTooltipUntyped from "discourse/float-kit/components/d-tooltip";
import type {
  BlockComponent,
  BlockEntry,
} from "discourse/lib/blocks/-internals/types";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import ArgsTable from "../shared/args-table";
import ConditionsTree from "./conditions-tree";

// TODO(devxp-typescript-pending): drop once DTooltip is authored in .gts with
// a real Signature, then import it directly. Untyped .gjs today → no
// arg/block/attr types; this shape reflects only this component's own usage.
const DTooltip = DTooltipUntyped as unknown as ComponentLike<{
  Args: {
    identifier: string;
    interactive: boolean;
    placement: string;
    maxWidth: number;
    triggers: { mobile: string[]; desktop: string[] };
    untriggers: { mobile: string[]; desktop: string[] };
  };
  Blocks: {
    trigger: [];
    content: [];
  };
}>;

interface BlockInfoSignature {
  Args: {
    /** The name of the block. */
    blockName: string;
    /** The block's unique ID (if set). */
    blockId?: string;
    /** The hierarchy path where the block is rendered. */
    debugLocation: string;
    /** Arguments passed to the block. */
    blockArgs?: Record<string, unknown>;
    /** Container arguments passed from parent container's childArgs. */
    containerArgs?: Record<string, unknown>;
    /** Conditions that were evaluated. */
    conditions?: BlockEntry["conditions"];
    /** Outlet arguments available to the block. */
    outletArgs?: Record<string, unknown>;
    /** The actual block component to render. */
    WrappedComponent: BlockComponent;
  };
}

/**
 * Visual overlay component for rendered blocks.
 * Wraps a block with debug information including name badge and tooltip.
 */
export default class BlockInfo extends Component<BlockInfoSignature> {
  /**
   * Checks whether this block has any conditions configured.
   * Used to conditionally render the conditions section in the tooltip.
   *
   * @returns True if the block has conditions defined.
   */
  get hasConditions(): boolean {
    return this.args.conditions != null;
  }

  /**
   * Checks whether this block has any arguments passed to it.
   * Used to conditionally render the arguments section in the tooltip.
   *
   * @returns True if the block has at least one argument.
   */
  get hasArgs(): boolean {
    return (
      this.args.blockArgs != null && Object.keys(this.args.blockArgs).length > 0
    );
  }

  /**
   * Checks whether this block has container args from a parent container.
   * Used to conditionally render the container args section in the tooltip.
   *
   * @returns True if the block has container args.
   */
  get hasContainerArgs(): boolean {
    return (
      this.args.containerArgs != null &&
      Object.keys(this.args.containerArgs).length > 0
    );
  }

  /**
   * Checks whether this block has outlet args available.
   * Used to conditionally render the outlet args section in the tooltip.
   *
   * @returns True if outlet args are available.
   */
  get hasOutletArgs(): boolean {
    return (
      this.args.outletArgs != null &&
      Object.keys(this.args.outletArgs).length > 0
    );
  }

  /**
   * Checks whether the tooltip has no content to display.
   * Used to show an "empty" message when there are no conditions, args,
   * container args, or outlet args.
   *
   * @returns True if there is nothing to display in the tooltip.
   */
  get isEmpty(): boolean {
    return (
      !this.hasConditions &&
      !this.hasArgs &&
      !this.hasContainerArgs &&
      !this.hasOutletArgs
    );
  }

  /**
   * Returns the display name for the block, including ID if set.
   * Format: "blockName" or "blockName(#id)".
   *
   * @returns The display name.
   */
  get displayName(): string {
    if (this.args.blockId) {
      return `${this.args.blockName}(#${this.args.blockId})`;
    }
    return this.args.blockName;
  }

  <template>
    <div class="block-debug-info --rendered" data-block-name={{@blockName}}>
      <DTooltip
        @identifier="block-debug-info"
        @interactive={{true}}
        @placement="bottom-start"
        @maxWidth={{500}}
        @triggers={{hash
          mobile=(array "click")
          desktop=(array "hover" "click")
        }}
        @untriggers={{hash mobile=(array "click") desktop=(array "mouseleave")}}
      >
        <:trigger>
          <span class="block-debug-badge">
            {{dIcon "cube"}}
            <span class="block-debug-badge__name">{{this.displayName}}</span>
          </span>
        </:trigger>
        <:content>
          <div class="block-debug-tooltip">
            <div class="block-debug-tooltip__header">
              <div class="block-debug-tooltip__row">
                {{dIcon "cube"}}
                <span class="block-debug-tooltip__title">
                  {{this.displayName}}
                </span>
              </div>
              <div class="block-debug-tooltip__location">
                in
                {{@debugLocation}}
              </div>
            </div>

            {{#if this.hasConditions}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Conditions
                  <span class="--passed">(passed)</span></div>
                <ConditionsTree @conditions={{@conditions}} @passed={{true}} />
              </div>
            {{/if}}

            {{#if this.hasArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Arguments</div>
                <ArgsTable @args={{@blockArgs}} />
              </div>
            {{/if}}

            {{#if this.hasContainerArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Container Args</div>
                <ArgsTable @args={{@containerArgs}} />
              </div>
            {{/if}}

            {{#if this.hasOutletArgs}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">Outlet Args</div>
                <ArgsTable @args={{@outletArgs}} />
              </div>
            {{/if}}

            {{#if this.isEmpty}}
              <div class="block-debug-tooltip__empty">
                No conditions or arguments
              </div>
            {{/if}}
          </div>
        </:content>
      </DTooltip>
      <@WrappedComponent />
    </div>
  </template>
}
