import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { type ComponentLike } from "@glint/template";
import DTooltipUntyped from "discourse/float-kit/components/d-tooltip";
import { FAILURE_TYPE } from "discourse/lib/blocks/-internals/patterns";
import type {
  BlockComponent,
  BlockEntry,
} from "discourse/lib/blocks/-internals/types";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";
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

interface GhostBlockSignature {
  Args: {
    /** The name of the hidden block. */
    blockName: string;
    /** The block's unique ID (if set). */
    blockId?: string;
    /** The hierarchy path where the block would render. */
    debugLocation: string;
    /** Arguments that would have been passed to the block. */
    blockArgs?: Record<string, unknown>;
    /** Container arguments from parent container's childArgs. */
    containerArgs?: Record<string, unknown>;
    /** Conditions that failed evaluation. */
    conditions?: BlockEntry["conditions"];
    /** The failure type constant (a `FAILURE_TYPE` value). */
    failureType?: string;
    /** Optional custom display message (overrides type-based default). */
    failureReason?: string;
    /** Nested ghost children for containers. */
    children?: Array<{ Component: BlockComponent }> | null;
  };
}

/**
 * Ghost placeholder for blocks that are hidden.
 * Shows a dashed outline indicating where the block would render.
 *
 * Blocks can be hidden for several reasons:
 * - **Optional missing**: Block reference uses `?` suffix but isn't registered
 * - **Conditions failed**: Block is registered but conditions evaluated to false
 * - **No visible children**: Container block has no children that pass their conditions
 * - **Custom reason**: Container block chose not to render this child (e.g., head block's "hidden by priority")
 *
 * For container blocks hidden due to no visible children, nested ghost children
 * are rendered inside to show the full block tree structure.
 */
export default class GhostBlock extends Component<GhostBlockSignature> {
  /**
   * Returns the appropriate hint message based on why the block is hidden.
   * If a custom `failureReason` is provided, it is displayed directly.
   * Otherwise, a default message is generated based on the `failureType`.
   *
   * @returns The hint message to display.
   */
  get hintMessage(): string {
    if (this.args.failureReason) {
      return this.args.failureReason;
    }
    if (this.args.failureType === FAILURE_TYPE.OPTIONAL_MISSING) {
      return i18n("js.blocks.ghost_reasons.optional_missing_hint");
    }
    if (this.args.failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN) {
      return i18n("js.blocks.ghost_reasons.no_visible_children_hint");
    }
    return i18n("js.blocks.ghost_reasons.condition_failed_hint");
  }

  /**
   * Returns the section title for the status/conditions section.
   *
   * @returns Either "Status" or "Conditions".
   */
  get sectionTitle(): string {
    if (
      this.args.failureType === FAILURE_TYPE.OPTIONAL_MISSING ||
      this.args.failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN ||
      this.args.failureReason
    ) {
      return i18n("js.blocks.ghost.status");
    }
    return i18n("js.blocks.ghost.conditions");
  }

  /**
   * Returns the status text shown in parentheses.
   *
   * @returns The status text (e.g., "not registered", "failed").
   */
  get statusText(): string {
    if (this.args.failureType === FAILURE_TYPE.OPTIONAL_MISSING) {
      return i18n("js.blocks.ghost.not_registered");
    }
    if (this.args.failureType === FAILURE_TYPE.NO_VISIBLE_CHILDREN) {
      return i18n("js.blocks.ghost.no_visible_children");
    }
    if (this.args.failureReason) {
      return i18n("js.blocks.ghost.hidden");
    }
    return i18n("js.blocks.ghost.failed");
  }

  /**
   * Determines if the conditions tree should be shown.
   * Only shown when conditions actually failed (not for optional missing,
   * no visible children, or custom reason).
   *
   * @returns True if conditions tree should be rendered.
   */
  get showConditionsTree(): boolean {
    return (
      this.args.failureType !== FAILURE_TYPE.OPTIONAL_MISSING &&
      this.args.failureType !== FAILURE_TYPE.NO_VISIBLE_CHILDREN &&
      !this.args.failureReason
    );
  }

  /**
   * Checks if an args object has any entries.
   *
   * @param args - The arguments object to check.
   * @returns True if args is non-null and has at least one key.
   */
  hasArgs(args: Record<string, unknown> | undefined): boolean {
    return args != null && Object.keys(args).length > 0;
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
    <div class="block-debug-ghost" data-block-name={{@blockName}}>
      <DTooltip
        @identifier="block-debug-ghost"
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
          <span class="block-debug-ghost__badge">
            {{dIcon "cube"}}
            <span class="block-debug-ghost__name">
              {{this.displayName}}
            </span>
            <span class="block-debug-ghost__status">
              ({{i18n "js.blocks.ghost.hidden"}})
            </span>
          </span>
        </:trigger>
        <:content>
          <div class="block-debug-tooltip --ghost">
            <div class="block-debug-tooltip__header --failed">
              <div class="block-debug-tooltip__row">
                {{dIcon "cube"}}
                <span class="block-debug-tooltip__title">
                  {{this.displayName}}
                </span>
                <span class="block-debug-tooltip__status">
                  {{i18n "js.blocks.ghost.hidden"}}
                </span>
              </div>
              <div class="block-debug-tooltip__location">
                {{i18n "js.blocks.ghost.in_location"}}
                {{@debugLocation}}
              </div>
            </div>

            <div class="block-debug-tooltip__section">
              <div class="block-debug-tooltip__section-title">
                {{this.sectionTitle}}
                <span class="--failed">({{this.statusText}})</span>
              </div>
              {{#if this.showConditionsTree}}
                <ConditionsTree @conditions={{@conditions}} @passed={{false}} />
              {{/if}}
            </div>

            {{#if (this.hasArgs @blockArgs)}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">
                  {{i18n "js.blocks.ghost.arguments"}}
                </div>
                <ArgsTable @args={{@blockArgs}} />
              </div>
            {{/if}}

            {{#if (this.hasArgs @containerArgs)}}
              <div class="block-debug-tooltip__section">
                <div class="block-debug-tooltip__section-title">
                  {{i18n "js.blocks.ghost.container_args"}}
                </div>
                <ArgsTable @args={{@containerArgs}} />
              </div>
            {{/if}}

            <div class="block-debug-tooltip__hint">
              {{this.hintMessage}}
            </div>
          </div>
        </:content>
      </DTooltip>

      {{! Render nested ghost children for container blocks with no visible children }}
      {{#if @children.length}}
        <div class="block-debug-ghost__children">
          {{#each @children as |child|}}
            <child.Component />
          {{/each}}
        </div>
      {{/if}}
    </div>
  </template>
}
