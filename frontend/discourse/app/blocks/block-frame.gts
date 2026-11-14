import Component from "@glimmer/component";
import { concat, hash } from "@ember/helper";
import type { ArgSchema } from "discourse/blocks/types";
import { ICON_NAME_PATTERN, URL_PATTERN } from "discourse/lib/blocks";
import { and } from "discourse/truth-helpers";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import dIcon from "discourse/ui-kit/helpers/d-icon";
import { i18n } from "discourse-i18n";

/**
 * How a list block presents itself:
 * - `plain`: the block's own look.
 * - `panel`: a card with an icon and title header and a "Show all" footer.
 * - `heading`: a large title and link above the rows, which sit in a card.
 */
export const FRAME_STYLES = ["plain", "panel", "heading"] as const;

/** One of {@link FRAME_STYLES}. */
export type FrameStyle = (typeof FRAME_STYLES)[number];

const FRAMED_STYLES: readonly FrameStyle[] = ["panel", "heading"];

/**
 * The args a block spreads into its schema to offer the frame styles.
 *
 * @param options - How the block uses the frame.
 * @returns Arg schema entries keyed by arg name.
 */
export function frameArgs({
  defaultIcon,
  withLink = false,
}: {
  /** Icon the panel header shows until changed. */
  defaultIcon: string;
  /**
   * Also declare `linkLabel` / `linkHref`, for blocks that don't have a link
   * of their own. They only apply when framed.
   */
  withLink?: boolean;
}): Record<string, ArgSchema> {
  const group = i18n("blocks.frame.group");
  const args: Record<string, ArgSchema> = {
    frameStyle: {
      type: "string",
      default: "panel",
      enum: [...FRAME_STYLES],
      ui: {
        control: "segmented",
        group,
        label: i18n("blocks.frame.style"),
        optionLabels: {
          plain: i18n("blocks.frame.styles.plain"),
          panel: i18n("blocks.frame.styles.panel"),
          heading: i18n("blocks.frame.styles.heading"),
        },
      },
    },
    icon: {
      type: "string",
      default: defaultIcon,
      pattern: ICON_NAME_PATTERN,
      ui: {
        control: "icon",
        group,
        label: i18n("blocks.frame.icon"),
        conditional: { arg: "frameStyle", equals: "panel" },
      },
    },
  };

  if (withLink) {
    args.linkLabel = {
      type: "string",
      ui: {
        group,
        label: i18n("blocks.frame.link_label"),
        placeholder: i18n("blocks.frame.show_all"),
        conditional: { arg: "frameStyle", oneOf: FRAMED_STYLES },
      },
    };
    args.linkHref = {
      type: "string",
      pattern: URL_PATTERN,
      ui: {
        control: "url",
        group,
        label: i18n("blocks.frame.link_href"),
        conditional: { arg: "frameStyle", oneOf: FRAMED_STYLES },
      },
    };
  }

  return args;
}

interface BlockFrameSignature {
  Args: {
    /** The presentation; anything unknown renders plain. */
    frameStyle?: string;
    /** Icon in the panel header. */
    icon?: string;
    /** The block's title. */
    title?: string;
    /** Destination of the "Show all" link. */
    linkHref?: string;
    /** Text of the "Show all" link. */
    linkLabel?: string;
    /**
     * Run the body edge to edge in a panel, for content that brings its own
     * inner spacing (a table, for instance).
     */
    flush?: boolean;
  };
  Blocks: {
    /** The block's content. */
    default: [
      frame: {
        /**
         * Whether the block renders its own look, title and link included.
         * When false the frame owns them and the block renders only its body.
         */
        isPlain: boolean;
      },
    ];
  };
}

/**
 * The shared chrome list blocks render inside. Plain leaves the block as it
 * is; the other styles draw the title, icon and link around the block's body.
 * Rows the frame should space and divide carry `d-block-frame__row`, inside a
 * list with `d-block-frame__rows`; the element wrapping the body carries
 * `d-block-frame__content`, which drops the block's own card styling.
 */
export default class BlockFrame extends Component<BlockFrameSignature> {
  get frameStyle(): FrameStyle {
    const style = this.args.frameStyle as FrameStyle;
    return FRAME_STYLES.includes(style) ? style : "plain";
  }

  get isPlain(): boolean {
    return this.frameStyle === "plain";
  }

  get isPanel(): boolean {
    return this.frameStyle === "panel";
  }

  get linkLabel(): string {
    return this.args.linkLabel?.trim() || i18n("blocks.frame.show_all");
  }

  <template>
    {{#if this.isPlain}}
      {{yield (hash isPlain=true)}}
    {{else}}
      <section
        class={{dConcatClass "d-block-frame" (concat "--" this.frameStyle)}}
      >
        {{#if @title}}
          <header class="d-block-frame__header">
            {{#if (and this.isPanel @icon)}}
              <span class="d-block-frame__icon">{{dIcon @icon}}</span>
            {{/if}}
            {{#if this.isPanel}}
              <h3 class="d-block-frame__title">{{@title}}</h3>
            {{else}}
              <h2 class="d-block-frame__title">{{@title}}</h2>
              {{#if @linkHref}}
                <a class="d-block-frame__link" href={{@linkHref}}>
                  {{this.linkLabel}}
                  {{dIcon "arrow-right"}}
                </a>
              {{/if}}
            {{/if}}
          </header>
        {{/if}}

        <div class={{dConcatClass "d-block-frame__body" (if @flush "--flush")}}>
          {{yield (hash isPlain=false)}}
        </div>

        {{#if (and this.isPanel @linkHref)}}
          <footer class="d-block-frame__footer">
            <a class="d-block-frame__link" href={{@linkHref}}>
              {{this.linkLabel}}
              {{dIcon "arrow-right"}}
            </a>
          </footer>
        {{/if}}
      </section>
    {{/if}}
  </template>
}
