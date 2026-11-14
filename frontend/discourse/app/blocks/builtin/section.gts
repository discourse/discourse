import Component from "@glimmer/component";
import { trustHTML } from "@ember/template";
import { block } from "discourse/blocks";
import BlockImage from "discourse/blocks/block-image";
import type { BlockImageValue } from "discourse/blocks/image-value";
import { HEX_COLOR_PATTERN } from "discourse/lib/blocks";
import { debugHooks } from "discourse/lib/blocks/-internals/debug-hooks";
import type { ChildBlockResult } from "discourse/lib/blocks/-internals/types";
import { i18n } from "discourse-i18n";

const SURFACES = ["transparent", "default", "subtle", "accent", "custom"];
const SCRIMS = ["none", "subtle", "medium", "strong"];
const PADDINGS = ["none", "small", "medium", "large"];
const GAPS = ["none", "small", "medium", "large"];
const CONTENT_WIDTHS = ["full", "wide", "narrow"];
const MIN_HEIGHTS = ["content", "small", "medium", "large", "viewport"];
const VERTICAL_ALIGNS = ["start", "center", "end"];

interface SectionSignature {
  Args: {
    children?: ChildBlockResult[];
    surface?: string;
    backgroundColor?: string;
    backgroundImage?: BlockImageValue;
    scrim?: string;
    padding?: string;
    gap?: string;
    contentWidth?: string;
    minHeight?: string;
    verticalAlign?: string;
    accessibleLabel?: string;
  };
}

@block("section", {
  thumbnail: () => import("discourse/blocks/thumbnails/section"),
  container: true,
  displayName: i18n("blocks.builtin.section.name"),
  icon: "layer-group",
  category: "layout",
  description: i18n("blocks.builtin.section.description"),
  args: {
    surface: {
      type: "string",
      default: "transparent",
      enum: SURFACES,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.background"),
        label: i18n("blocks.builtin.section.surface"),
        optionLabels: {
          transparent: i18n("blocks.builtin.section.options.transparent"),
          default: i18n("blocks.builtin.section.options.default"),
          subtle: i18n("blocks.builtin.section.options.subtle"),
          accent: i18n("blocks.builtin.section.options.accent"),
          custom: i18n("blocks.builtin.section.options.custom"),
        },
      },
    },
    backgroundColor: {
      type: "string",
      pattern: HEX_COLOR_PATTERN,
      ui: {
        control: "color",
        group: i18n("blocks.builtin.section.groups.background"),
        label: i18n("blocks.builtin.section.background_color"),
        conditional: { arg: "surface", equals: "custom" },
      },
    },
    backgroundImage: {
      type: "image",
      allowDark: true,
      allowResize: false,
      allowComposition: true,
      aspectRatio: "auto",
      defaultFit: "cover",
      ui: {
        group: i18n("blocks.builtin.section.groups.background"),
        label: i18n("blocks.builtin.section.background_image"),
      },
    },
    scrim: {
      type: "string",
      default: "medium",
      enum: SCRIMS,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.background"),
        label: i18n("blocks.builtin.section.scrim"),
        optionLabels: {
          none: i18n("blocks.builtin.section.options.none"),
          subtle: i18n("blocks.builtin.section.options.subtle"),
          medium: i18n("blocks.builtin.section.options.medium"),
          strong: i18n("blocks.builtin.section.options.strong"),
        },
      },
    },
    padding: {
      type: "string",
      default: "medium",
      enum: PADDINGS,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.layout"),
        label: i18n("blocks.builtin.section.padding"),
        optionLabels: {
          none: i18n("blocks.builtin.section.options.none"),
          small: i18n("blocks.builtin.section.options.small"),
          medium: i18n("blocks.builtin.section.options.medium"),
          large: i18n("blocks.builtin.section.options.large"),
        },
      },
    },
    gap: {
      type: "string",
      default: "medium",
      enum: GAPS,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.layout"),
        label: i18n("blocks.builtin.section.gap"),
        helpText: i18n("blocks.builtin.section.gap_help"),
        optionLabels: {
          none: i18n("blocks.builtin.section.options.none"),
          small: i18n("blocks.builtin.section.options.small"),
          medium: i18n("blocks.builtin.section.options.medium"),
          large: i18n("blocks.builtin.section.options.large"),
        },
      },
    },
    contentWidth: {
      type: "string",
      default: "full",
      enum: CONTENT_WIDTHS,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.layout"),
        label: i18n("blocks.builtin.section.content_width"),
        optionLabels: {
          full: i18n("blocks.builtin.section.options.full"),
          wide: i18n("blocks.builtin.section.options.wide"),
          narrow: i18n("blocks.builtin.section.options.narrow"),
        },
      },
    },
    minHeight: {
      type: "string",
      default: "content",
      enum: MIN_HEIGHTS,
      ui: {
        control: "select",
        group: i18n("blocks.builtin.section.groups.layout"),
        label: i18n("blocks.builtin.section.min_height"),
        optionLabels: {
          content: i18n("blocks.builtin.section.options.content"),
          small: i18n("blocks.builtin.section.options.small"),
          medium: i18n("blocks.builtin.section.options.medium"),
          large: i18n("blocks.builtin.section.options.large"),
          viewport: i18n("blocks.builtin.section.options.viewport"),
        },
      },
    },
    verticalAlign: {
      type: "string",
      default: "start",
      enum: VERTICAL_ALIGNS,
      ui: {
        control: "segmented",
        group: i18n("blocks.builtin.section.groups.layout"),
        label: i18n("blocks.builtin.section.vertical_align"),
        optionLabels: {
          start: i18n("blocks.builtin.section.options.start"),
          center: i18n("blocks.builtin.section.options.center"),
          end: i18n("blocks.builtin.section.options.end"),
        },
      },
    },
    accessibleLabel: {
      type: "string",
      default: "",
      ui: {
        group: i18n("blocks.builtin.section.groups.accessibility"),
        label: i18n("blocks.builtin.section.accessible_label"),
        helpText: i18n("blocks.builtin.section.accessible_label_help"),
      },
    },
  },
})
export default class Section extends Component<SectionSignature> {
  get isEditing(): boolean {
    return debugHooks.isEditPresentation;
  }

  get accessibleLabel(): string | undefined {
    return this.args.accessibleLabel?.trim() || undefined;
  }

  get hasScrim(): boolean {
    return Boolean(this.args.backgroundImage?.url && this.scrim !== "none");
  }

  get scrim(): string {
    return validChoice(this.args.scrim, SCRIMS, "medium");
  }

  get backgroundStyle(): ReturnType<typeof trustHTML> | undefined {
    const color = this.args.backgroundColor;
    if (this.surface === "custom" && color && HEX_COLOR_PATTERN.test(color)) {
      return trustHTML(`background-color: ${color};`);
    }
  }

  get surface(): string {
    return validChoice(this.args.surface, SURFACES, "transparent");
  }

  get className(): string {
    const padding = validChoice(this.args.padding, PADDINGS, "medium");
    const gap = validChoice(this.args.gap, GAPS, "medium");
    const width = validChoice(this.args.contentWidth, CONTENT_WIDTHS, "full");
    const height = validChoice(this.args.minHeight, MIN_HEIGHTS, "content");
    const align = validChoice(
      this.args.verticalAlign,
      VERTICAL_ALIGNS,
      "start"
    );

    return [
      "d-block-section",
      `--surface-${this.surface}`,
      `--scrim-${this.scrim}`,
      `--padding-${padding}`,
      `--gap-${gap}`,
      `--width-${width}`,
      `--height-${height}`,
      `--align-${align}`,
    ].join(" ");
  }

  <template>
    <section
      aria-label={{this.accessibleLabel}}
      class={{this.className}}
      style={{this.backgroundStyle}}
    >
      <div
        class="d-block-section__backdrop"
        data-block-arg="backgroundImage"
        data-drop-passive
      >
        {{#if @backgroundImage.url}}
          <BlockImage @fill={{true}} @image={{@backgroundImage}} />
        {{/if}}
      </div>

      {{#if this.hasScrim}}
        <div class="d-block-section__scrim"></div>
      {{/if}}

      <div
        class="d-block-section__content"
        data-wf-drop-container={{if this.isEditing "true"}}
        data-wf-empty-host={{if this.isEditing "true"}}
      >
        {{#each @children key="key" as |child|}}
          <child.Component />
        {{/each}}
      </div>
    </section>
  </template>
}

function validChoice(
  value: string | undefined,
  choices: readonly string[],
  fallback: string
): string {
  return value && choices.includes(value) ? value : fallback;
}
