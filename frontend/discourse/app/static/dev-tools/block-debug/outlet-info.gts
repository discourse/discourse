import Component from "@glimmer/component";
import { array, hash } from "@ember/helper";
import { type ComponentLike } from "@glint/template";
import DTooltipUntyped from "discourse/float-kit/components/d-tooltip";
import { DEPRECATED_ARGS_KEY } from "discourse/lib/outlet-args";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import ArgsTable from "../shared/args-table";

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

interface OutletInfoSignature {
  Args: {
    /** The name of the block outlet. */
    outletName: string;
    /** Number of blocks registered. */
    blockCount: number;
    /** Arguments passed to the outlet. */
    outletArgs?: Record<string, unknown>;
    /** Validation error if config failed. */
    error?: Error | null;
  };
  Blocks: {
    /** Default block for rendering children. */
    default: [];
  };
}

/**
 * Debug overlay for BlockOutlet components.
 * Shows outlet name badge with a tooltip containing outlet info and GitHub search link.
 */
export default class OutletInfo extends Component<OutletInfoSignature> {
  /**
   * Returns a human-readable label for the block count.
   *
   * @returns "1 block" for singular, "N blocks" for plural.
   */
  get blockLabel(): string {
    const count = this.args.blockCount;
    return count === 1 ? "1 block" : `${count} blocks`;
  }

  /**
   * Cleans up the error message for display in the popup.
   * Removes the "[Blocks]" prefix while preserving formatted structure.
   *
   * @returns The cleaned error message.
   */
  get errorMessage(): string {
    let message = this.args.error?.message ?? "Unknown validation error";

    // Remove "[Blocks]" prefix that's added for console logging
    message = message.replace(/^\[Blocks\]\s*/i, "");

    return message.trim();
  }

  /**
   * Checks whether this outlet has any args passed to it.
   *
   * @returns True if outlet has at least one arg.
   */
  get hasOutletArgs(): boolean {
    const outletArgs = this.args.outletArgs;
    const deprecatedArgs = outletArgs?.[DEPRECATED_ARGS_KEY] as
      | Record<string, unknown>
      | undefined;

    return (
      (outletArgs != null && Object.keys(outletArgs).length > 0) ||
      (deprecatedArgs != null && Object.keys(deprecatedArgs).length > 0)
    );
  }

  <template>
    <div
      class={{dConcatClass
        "block-outlet-debug"
        (if @error "--validation-failed")
      }}
      data-outlet-name={{@outletName}}
    >
      <DTooltip
        @identifier="block-outlet-info"
        @interactive={{true}}
        @placement="bottom-start"
        @maxWidth={{400}}
        @triggers={{hash
          mobile=(array "click")
          desktop=(array "click" "hover")
        }}
        @untriggers={{hash mobile=(array "click") desktop=(array "click")}}
      >
        <:trigger>
          <span class="block-outlet-debug__badge {{if @error '--error'}}">
            {{dIcon "cubes"}}
            {{@outletName}}
          </span>
        </:trigger>
        <:content>
          <div class="outlet-info__wrapper">
            <div
              class="outlet-info__heading
                {{if @error '--error' '--block-outlet'}}"
            >
              <span class="title">
                {{dIcon "cubes"}}
                {{@outletName}}
              </span>
              {{#if @error}}
                <span class="outlet-info__status">ERROR</span>
              {{/if}}
              <a
                class="github-link"
                href="https://github.com/search?q=repo%3Adiscourse%2Fdiscourse%20BlockOutlet%20@name=%22{{@outletName}}%22&type=code"
                target="_blank"
                rel="noopener noreferrer"
                title="Find on GitHub"
              >{{dIcon "fab-github"}}</a>
            </div>
            <div class="outlet-info__content">
              {{#if @error}}
                <div class="outlet-info__error">
                  <div class="outlet-info__section-title">Validation failed</div>
                  <pre
                    class="outlet-info__error-message"
                  >{{this.errorMessage}}</pre>
                </div>
              {{else if @blockCount}}
                <div class="outlet-info__section">
                  <div class="outlet-info__section-title">Blocks Registered</div>
                  <div class="outlet-info__stat">
                    {{dIcon "cube"}}
                    <span>{{this.blockLabel}}</span>
                  </div>
                </div>
              {{else}}
                <div class="outlet-info__empty">
                  No blocks registered for this outlet
                </div>
              {{/if}}

              {{#if this.hasOutletArgs}}
                <div class="outlet-info__section">
                  <div class="outlet-info__section-title">Outlet Args</div>
                  <ArgsTable @args={{@outletArgs}} @prefix="block outlet" />
                </div>
              {{/if}}
            </div>
          </div>
        </:content>
      </DTooltip>
      {{yield}}
    </div>
  </template>
}
