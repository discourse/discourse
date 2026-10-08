import type { BlockImageValue } from "discourse/blocks/image-value";
import type {
  ArgSchema,
  ArgUiConditionalLeaf,
  ArgUiGroup,
  BlockValidationIssue,
} from "discourse/blocks/types";
import {
  ICON_NAME_PATTERN,
  URL_PATTERN,
} from "discourse/lib/blocks/-internals/arg-patterns";
import { i18n } from "discourse-i18n";
import { inlineText } from "./inline-text";

type RichInlineValue = string | { content?: unknown[] };

/** Completeness applies only to active features; schema validation handles supplied types. */
export function validateCard(
  args: Record<string, unknown>
): BlockValidationIssue[] {
  const errors: BlockValidationIssue[] = [];
  const href = inlineText(args.href);
  const label = inlineText(args.actionLabel);
  if (label && !href) {
    errors.push({
      field: "href",
      message: i18n("blocks.builtin.card.errors.primary_href"),
    });
  }
  if (href && !label && !args.wholeCard) {
    errors.push({
      field: "actionLabel",
      message: i18n("blocks.builtin.card.errors.primary_label"),
    });
  }
  if (args.wholeCard) {
    if (!href && !label) {
      errors.push({
        field: "href",
        message: i18n("blocks.builtin.card.errors.primary_href"),
      });
    }
    if (!label && !inlineText(args.linkLabel) && !inlineText(args.title)) {
      errors.push({
        field: "linkLabel",
        message: i18n("blocks.builtin.card.errors.link_name"),
      });
    }
  }
  if (args.secondaryEnabled) {
    for (const field of ["secondaryLabel", "secondaryHref"] as const) {
      if (!inlineText(args[field])) {
        errors.push({
          field,
          message: i18n("blocks.builtin.card.errors.secondary"),
        });
      }
    }
  }
  if (
    args.identityEnabled &&
    !inlineText(args.identityName) &&
    (inlineText(args.identityRole) || hasSource(args.avatar))
  ) {
    errors.push({
      field: "identityName",
      message: i18n("blocks.builtin.card.errors.identity_name"),
    });
  }
  if (
    args.presentation !== "none" &&
    hasSource(args.image) &&
    args.imageDecorative === false &&
    !inlineText(args.imageAlt)
  ) {
    errors.push({
      field: "imageAlt",
      message: i18n("blocks.builtin.card.errors.image_alt"),
    });
  }
  return errors;
}

function hasSource(value: unknown): boolean {
  return Boolean(
    value &&
    typeof value === "object" &&
    "url" in value &&
    inlineText(value.url)
  );
}

export interface CardArgs {
  /** Title. */
  title?: RichInlineValue;
  /** Body. */
  body?: RichInlineValue;
  /** Meta. */
  meta?: RichInlineValue;
  /** Presentation. */
  presentation?: "none" | "above" | "below" | "beside" | "behind";
  /** Image. */
  image?: BlockImageValue;
  /** Image width. */
  imageWidth?: "adaptive" | "even";
  /** Image side. */
  imageSide?: "start" | "end";
  /** Label. */
  eyebrow?: RichInlineValue;
  /** Icon. */
  icon?: string;
  /** Icon accompanies. */
  iconTarget?: "title" | "label";
  /** Icon style. */
  iconStyle?: "plain" | "tile";
  /** Label style. */
  labelStyle?: "plain" | "badge";
  /** Label placement. */
  labelPlacement?: "content" | "media";
  /** Show identity. */
  identityEnabled?: boolean;
  /** Name. */
  identityName?: RichInlineValue;
  /** Role. */
  identityRole?: RichInlineValue;
  /** Portrait. */
  avatar?: BlockImageValue;
  /** Portrait display. */
  avatarDisplay?: "image" | "initials" | "none";
  /** Identity format. */
  identityFormat?: "compact" | "feature" | "stacked";
  /** Identity placement. */
  identityPlacement?: "content" | "media";
  /** Portrait shape. */
  identityShape?: "circle" | "rounded";
  /** Media treatment. */
  identityTreatment?: "theme" | "photo";
  /** Primary link URL. */
  href?: string;
  /** Primary action label. */
  actionLabel?: string;
  /** Open primary in new tab. */
  external?: boolean;
  /** Link whole card. */
  wholeCard?: boolean;
  /** Whole-card link description. */
  linkLabel?: string;
  /** Show secondary action. */
  secondaryEnabled?: boolean;
  /** Secondary action label. */
  secondaryLabel?: string;
  /** Secondary link URL. */
  secondaryHref?: string;
  /** Open secondary in new tab. */
  secondaryExternal?: boolean;
  /** Action style. */
  actionStyle?: "link" | "button";
  /** Action layout. */
  actionLayout?: "below" | "inline";
  /** Surface. */
  surface?: "default" | "subtle" | "integrated" | "accent" | "contrast";
  /** Scale. */
  scale?: "compact" | "standard" | "featured";
  /** Show dividers. */
  dividers?: boolean;
  /** Heading level. */
  headingLevel?: number;
  /** Decorative image. */
  imageDecorative?: boolean;
  /** Alternative text. */
  imageAlt?: string;
}

function disclosure(
  name: "label" | "identity" | "actions" | "appearance" | "advanced"
): ArgUiGroup {
  return {
    name,
    label: i18n(`blocks.builtin.card.groups.${name}`),
    collapsed: true,
  };
}

const mediaVisible: ArgUiConditionalLeaf = {
  arg: "presentation",
  oneOf: ["above", "below", "beside", "behind"],
};

const identityVisible: ArgUiConditionalLeaf = {
  arg: "identityEnabled",
  equals: true,
};

const mediaIdentity: ArgUiConditionalLeaf[] = [
  identityVisible,
  { arg: "image", notEmpty: true },
  { arg: "presentation", oneOf: ["above", "below"] },
];

export const cardArgs: Record<keyof CardArgs, ArgSchema> = {
  title: {
    type: "richInline",
    ui: {
      group: i18n("blocks.builtin.card.groups.content"),
      label: i18n("blocks.builtin.card.title"),
      control: "rich-inline",
      schema: "paragraph",
    },
  },
  body: {
    type: "richInline",
    ui: {
      group: i18n("blocks.builtin.card.groups.content"),
      label: i18n("blocks.builtin.card.body"),
      control: "rich-inline",
      schema: "paragraph",
    },
  },
  meta: {
    type: "richInline",
    ui: {
      group: i18n("blocks.builtin.card.groups.content"),
      label: i18n("blocks.builtin.card.meta"),
      control: "rich-inline",
      schema: "plain",
    },
  },
  presentation: {
    type: "string",
    default: "above",
    enum: ["none", "above", "below", "beside", "behind"],
    ui: {
      group: i18n("blocks.builtin.card.groups.composition"),
      label: i18n("blocks.builtin.card.presentation"),
      control: "select",
      optionLabels: {
        none: i18n("blocks.builtin.card.options.none"),
        above: i18n("blocks.builtin.card.options.above"),
        below: i18n("blocks.builtin.card.options.below"),
        beside: i18n("blocks.builtin.card.options.beside"),
        behind: i18n("blocks.builtin.card.options.behind"),
      },
    },
  },
  image: {
    type: "image",
    allowDark: true,
    allowComposition: true,
    allowResize: false,
    aspectRatio: "auto",
    defaultFit: "cover",
    ui: {
      conditional: mediaVisible,
      group: i18n("blocks.builtin.card.groups.composition"),
      label: i18n("blocks.builtin.card.image"),
    },
  },
  imageWidth: {
    type: "string",
    default: "adaptive",
    enum: ["adaptive", "even"],
    ui: {
      conditional: { arg: "presentation", equals: "beside" },
      group: i18n("blocks.builtin.card.groups.composition"),
      label: i18n("blocks.builtin.card.image_width"),
      control: "select",
      optionLabels: {
        adaptive: i18n("blocks.builtin.card.options.adaptive"),
        even: i18n("blocks.builtin.card.options.even"),
      },
    },
  },
  imageSide: {
    type: "string",
    default: "start",
    enum: ["start", "end"],
    ui: {
      conditional: { arg: "presentation", equals: "beside" },
      group: i18n("blocks.builtin.card.groups.composition"),
      label: i18n("blocks.builtin.card.image_side"),
      control: "select",
      optionLabels: {
        start: i18n("blocks.builtin.card.options.start"),
        end: i18n("blocks.builtin.card.options.end"),
      },
    },
  },
  eyebrow: {
    type: "richInline",
    ui: {
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.eyebrow"),
      control: "rich-inline",
      schema: "plain",
    },
  },
  icon: {
    type: "string",
    pattern: ICON_NAME_PATTERN,
    ui: {
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.icon"),
      control: "icon",
    },
  },
  iconTarget: {
    type: "string",
    default: "title",
    enum: ["title", "label"],
    ui: {
      conditional: { arg: "icon", notEmpty: true },
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.icon_target"),
      control: "select",
      optionLabels: {
        title: i18n("blocks.builtin.card.options.title"),
        label: i18n("blocks.builtin.card.options.label"),
      },
    },
  },
  iconStyle: {
    type: "string",
    default: "plain",
    enum: ["plain", "tile"],
    ui: {
      conditional: { arg: "icon", notEmpty: true },
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.icon_style"),
      control: "select",
      optionLabels: {
        plain: i18n("blocks.builtin.card.options.plain"),
        tile: i18n("blocks.builtin.card.options.tile"),
      },
    },
  },
  labelStyle: {
    type: "string",
    default: "plain",
    enum: ["plain", "badge"],
    ui: {
      conditional: { arg: "eyebrow", notEmpty: true },
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.label_style"),
      control: "select",
      optionLabels: {
        plain: i18n("blocks.builtin.card.options.plain"),
        badge: i18n("blocks.builtin.card.options.badge"),
      },
    },
  },
  labelPlacement: {
    type: "string",
    default: "content",
    enum: ["content", "media"],
    ui: {
      conditional: {
        all: [
          { arg: "presentation", equals: "behind" },
          { arg: "image", notEmpty: true },
        ],
      },
      group: disclosure("label"),
      label: i18n("blocks.builtin.card.label_placement"),
      control: "select",
      optionLabels: {
        content: i18n("blocks.builtin.card.options.content"),
        media: i18n("blocks.builtin.card.options.media"),
      },
    },
  },
  identityEnabled: {
    type: "boolean",
    default: false,
    ui: {
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_enabled"),
      control: "toggle",
    },
  },
  identityName: {
    type: "richInline",
    ui: {
      conditional: identityVisible,
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_name"),
      control: "rich-inline",
      schema: "plain",
    },
  },
  identityRole: {
    type: "richInline",
    ui: {
      conditional: identityVisible,
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_role"),
      control: "rich-inline",
      schema: "plain",
    },
  },
  avatar: {
    type: "image",
    allowDark: true,
    allowComposition: true,
    allowResize: false,
    aspectRatio: "auto",
    defaultFit: "cover",
    ui: {
      conditional: {
        all: [identityVisible, { arg: "avatarDisplay", equals: "image" }],
      },
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.avatar"),
    },
  },
  avatarDisplay: {
    type: "string",
    default: "image",
    enum: ["image", "initials", "none"],
    ui: {
      conditional: identityVisible,
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.avatar_display"),
      control: "select",
      optionLabels: {
        image: i18n("blocks.builtin.card.options.image"),
        initials: i18n("blocks.builtin.card.options.initials"),
        none: i18n("blocks.builtin.card.options.none"),
      },
    },
  },
  identityFormat: {
    type: "string",
    default: "compact",
    enum: ["compact", "feature", "stacked"],
    ui: {
      conditional: identityVisible,
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_format"),
      control: "select",
      optionLabels: {
        compact: i18n("blocks.builtin.card.options.compact"),
        feature: i18n("blocks.builtin.card.options.feature"),
        stacked: i18n("blocks.builtin.card.options.stacked"),
      },
    },
  },
  identityPlacement: {
    type: "string",
    default: "content",
    enum: ["content", "media"],
    ui: {
      conditional: { all: mediaIdentity },
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_placement"),
      control: "select",
      optionLabels: {
        content: i18n("blocks.builtin.card.options.content"),
        media: i18n("blocks.builtin.card.options.media"),
      },
    },
  },
  identityShape: {
    type: "string",
    default: "circle",
    enum: ["circle", "rounded"],
    ui: {
      conditional: {
        all: [
          identityVisible,
          { arg: "avatarDisplay", oneOf: ["image", "initials"] },
        ],
      },
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_shape"),
      control: "select",
      optionLabels: {
        circle: i18n("blocks.builtin.card.options.circle"),
        rounded: i18n("blocks.builtin.card.options.rounded"),
      },
    },
  },
  identityTreatment: {
    type: "string",
    default: "theme",
    enum: ["theme", "photo"],
    ui: {
      conditional: {
        all: [...mediaIdentity, { arg: "identityPlacement", equals: "media" }],
      },
      group: disclosure("identity"),
      label: i18n("blocks.builtin.card.identity_treatment"),
      control: "select",
      optionLabels: {
        theme: i18n("blocks.builtin.card.options.theme"),
        photo: i18n("blocks.builtin.card.options.photo"),
      },
    },
  },
  href: {
    type: "string",
    pattern: URL_PATTERN,
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.href"),
      control: "url",
    },
  },
  actionLabel: {
    type: "string",
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.action_label"),
    },
  },
  external: {
    type: "boolean",
    default: false,
    ui: {
      conditional: { arg: "href", notEmpty: true },
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.external"),
      control: "toggle",
    },
  },
  wholeCard: {
    type: "boolean",
    default: false,
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.whole_card"),
      control: "toggle",
    },
  },
  linkLabel: {
    type: "string",
    ui: {
      conditional: {
        all: [
          { arg: "wholeCard", equals: true },
          { arg: "actionLabel", notEmpty: false },
        ],
      },
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.link_label"),
    },
  },
  secondaryEnabled: {
    type: "boolean",
    default: false,
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.secondary_enabled"),
      control: "toggle",
    },
  },
  secondaryLabel: {
    type: "string",
    ui: {
      conditional: { arg: "secondaryEnabled", equals: true },
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.secondary_label"),
    },
  },
  secondaryHref: {
    type: "string",
    pattern: URL_PATTERN,
    ui: {
      conditional: { arg: "secondaryEnabled", equals: true },
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.secondary_href"),
      control: "url",
    },
  },
  secondaryExternal: {
    type: "boolean",
    default: false,
    ui: {
      conditional: { arg: "secondaryEnabled", equals: true },
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.secondary_external"),
      control: "toggle",
    },
  },
  actionStyle: {
    type: "string",
    default: "link",
    enum: ["link", "button"],
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.action_style"),
      control: "select",
      optionLabels: {
        link: i18n("blocks.builtin.card.options.link"),
        button: i18n("blocks.builtin.card.options.button"),
      },
    },
  },
  actionLayout: {
    type: "string",
    default: "below",
    enum: ["below", "inline"],
    ui: {
      group: disclosure("actions"),
      label: i18n("blocks.builtin.card.action_layout"),
      control: "select",
      optionLabels: {
        below: i18n("blocks.builtin.card.options.below"),
        inline: i18n("blocks.builtin.card.options.inline"),
      },
    },
  },
  surface: {
    type: "string",
    default: "default",
    enum: ["default", "subtle", "integrated", "accent", "contrast"],
    ui: {
      group: disclosure("appearance"),
      label: i18n("blocks.builtin.card.surface"),
      control: "select",
      optionLabels: {
        default: i18n("blocks.builtin.card.options.default"),
        subtle: i18n("blocks.builtin.card.options.subtle"),
        integrated: i18n("blocks.builtin.card.options.integrated"),
        accent: i18n("blocks.builtin.card.options.accent"),
        contrast: i18n("blocks.builtin.card.options.contrast"),
      },
    },
  },
  scale: {
    type: "string",
    default: "standard",
    enum: ["compact", "standard", "featured"],
    ui: {
      group: disclosure("appearance"),
      label: i18n("blocks.builtin.card.scale"),
      control: "select",
      optionLabels: {
        compact: i18n("blocks.builtin.card.options.compact"),
        standard: i18n("blocks.builtin.card.options.standard"),
        featured: i18n("blocks.builtin.card.options.featured"),
      },
    },
  },
  dividers: {
    type: "boolean",
    default: false,
    ui: {
      group: disclosure("appearance"),
      label: i18n("blocks.builtin.card.dividers"),
      control: "toggle",
    },
  },
  headingLevel: {
    type: "number",
    default: 3,
    integer: true,
    enum: [2, 3, 4, 5, 6],
    ui: {
      group: disclosure("advanced"),
      label: i18n("blocks.builtin.card.heading_level"),
    },
  },
  imageDecorative: {
    type: "boolean",
    default: true,
    ui: {
      conditional: { all: [mediaVisible, { arg: "image", notEmpty: true }] },
      group: disclosure("advanced"),
      label: i18n("blocks.builtin.card.image_decorative"),
      control: "toggle",
    },
  },
  imageAlt: {
    type: "string",
    ui: {
      conditional: {
        all: [
          mediaVisible,
          { arg: "image", notEmpty: true },
          { arg: "imageDecorative", equals: false },
        ],
      },
      group: disclosure("advanced"),
      label: i18n("blocks.builtin.card.image_alt"),
    },
  },
};
