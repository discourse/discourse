/* eslint-disable prefer-const -- Preserve the original JavaScript emit for this types-only port. */
import { get } from "@ember/object";
import { trustHTML } from "@ember/template";
import categoryVariables from "discourse/helpers/category-variables";
import categoryStyleType from "discourse/lib/category-style-type";
import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { iconHTML } from "discourse/lib/icon-library";
import { applyValueTransformer } from "discourse/lib/transformer";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import type SiteSettingsService from "discourse/services/site-settings";
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

/** The category properties a badge reads. */
export interface CategoryBadgeCategory {
  id?: number | string;
  name?: string;
  slug?: string | null;
  color?: string | null;
  textColor?: string | null;
  style_type?: string | null;
  icon?: string | null;
  emoji?: string | null;
  read_restricted?: boolean;
  parent_category_id?: number | null;
  parentCategory?: CategoryBadgeCategory | null;
}

/** Options for a category badge. */
export interface CategoryBadgeOptions {
  /** The url that we want the category badge to link to. */
  url?: string;

  /** If false, returns an empty string for the uncategorized category. */
  allowUncategorized?: boolean;

  /** If false, the category badge will not be a link. */
  link?: boolean | "false";

  /** If true, parent category will be hidden in the badge. */
  hideParent?: boolean;

  /** If true, category color will be set as an inline style. */
  previewColor?: boolean;

  /** The ancestors of the category to generate the badge for. */
  ancestors?: CategoryBadgeCategory[];

  /** Badge style, either "icon", "emoji" or "square" (default). */
  styleType?: string;

  /** The emoji to use for the badge (if styleType is "emoji"). */
  emoji?: string | null;

  /** The icon to use for the badge (if styleType is "icon"). */
  icon?: string | null;

  /** Additional wrapper classes. */
  extraClasses?: string;

  /** Topic count displayed after the badge. */
  topicCount?: number;

  /** Whether to display the subcategory indicator. */
  hasSubcategories?: boolean;

  /** Whether to display the read-only indicator. */
  readOnly?: boolean;
}

/** Renders a category badge as HTML. */
export type CategoryLinkRenderer = (
  category: CategoryBadgeCategory,
  opts: CategoryBadgeOptions
) => string;

/** Returns the id of an extra icon for a category's badge, if it has one. */
export type ExtraIconRenderer = (
  category: CategoryBadgeCategory
) => string | null | undefined;

/**
 * TODO(typescript-pending): `SiteSettingsService` does not declare its setting keys, so
 * this types the settings read here. Remove it once the service types its settings.
 */
interface BadgeSettings {
  suppress_uncategorized_badge: boolean;
  support_mixed_text_direction: boolean;
}

let _renderer: CategoryLinkRenderer = defaultCategoryLinkRenderer;

/**
 * Replaces the function that renders category badges.
 *
 * @param fn - The renderer.
 */
export function replaceCategoryLinkRenderer(fn: CategoryLinkRenderer) {
  _renderer = fn;
}

let _extraIconRenderers: ExtraIconRenderer[] = [];

/**
 * Registers a function that adds an icon to category badges.
 *
 * @param renderer - Returns the icon id for a category, if it has one.
 */
export function addExtraIconRenderer(renderer: ExtraIconRenderer) {
  _extraIconRenderers.push(renderer);
}

/**
 * Generates category badge HTML.
 *
 * @param category - The category to generate the badge for.
 * @param opts - The options. They are changed in place.
 * @returns The badge HTML, or `""` without a category or for a suppressed
 *   uncategorized badge.
 */
export function categoryBadgeHTML(
  category?: CategoryBadgeCategory | null,
  opts?: CategoryBadgeOptions | null
): string {
  const { site, siteSettings } = helperContext();
  opts = opts || {};

  if (
    !category ||
    (!opts.allowUncategorized &&
      get(category, "id") === site.uncategorized_category_id &&
      (siteSettings as SiteSettingsService & BadgeSettings)
        .suppress_uncategorized_badge)
  ) {
    return "";
  }

  if (!opts.styleType) {
    opts.styleType = categoryStyleType(category.style_type) || "square";

    if (opts.styleType === "icon") {
      opts.icon = opts.icon || category.icon;
    } else if (opts.styleType === "emoji") {
      opts.emoji = opts.emoji || category.emoji;
    }
  }

  if (opts.ancestors) {
    const { ancestors, readOnly, ...newOpts } = opts;

    // allow each ancestor to use its own style
    ["styleType", "icon", "emoji"].forEach(
      (k) => delete (newOpts as Record<string, unknown>)[k]
    );

    return [category, ...ancestors]
      .reverse()
      .map((c) => {
        return categoryBadgeHTML(c, {
          ...newOpts,
          ...(c !== category ? { topicCount: undefined } : {}),
          ...(readOnly && c === category ? { readOnly } : {}),
        });
      })
      .join("");
  }

  return _renderer(category, opts);
}

/**
 * Generates trusted category badge HTML from the options a template passes.
 *
 * @param category - The category to generate the badge for.
 * @param options - The options. Only some are passed on.
 * @returns The badge HTML.
 */
export function categoryLinkHTML(
  category?: CategoryBadgeCategory | null,
  options?: (CategoryBadgeOptions & { hash?: CategoryBadgeOptions }) | null
) {
  let categoryOptions: CategoryBadgeOptions = {};

  // TODO: This is a compatibility layer with the old helper structure.
  // Can be removed once we migrate to `registerUnbound` fully
  if (options && options.hash) {
    options = options.hash;
  }

  if (options) {
    if (options.allowUncategorized) {
      categoryOptions.allowUncategorized = true;
    }
    if (options.link !== undefined) {
      categoryOptions.link = options.link;
    }
    if (options.previewColor) {
      categoryOptions.previewColor = true;
    }
    if (options.extraClasses) {
      categoryOptions.extraClasses = options.extraClasses;
    }
    if (options.hideParent) {
      categoryOptions.hideParent = true;
    }
    if (options.ancestors) {
      categoryOptions.ancestors = options.ancestors;
    }
    if (options.styleType) {
      categoryOptions.styleType = options.styleType;
    }
    if (options.icon) {
      categoryOptions.icon = options.icon;
    }
    if (options.emoji) {
      categoryOptions.emoji = options.emoji;
    }
  }
  return trustHTML(categoryBadgeHTML(category, categoryOptions));
}

/**
 * Renders a category badge.
 *
 * @param args - The arguments for `categoryLinkHTML`.
 * @returns The badge HTML.
 */
export default function dCategoryLink(
  ...args: Parameters<typeof categoryLinkHTML>
) {
  return categoryLinkHTML(...args);
}

function buildTopicCount(count: number) {
  return `<span class="topic-count" aria-label="${i18n(
    "category_row.topic_count",
    { count }
  )}">&times; ${count}</span>`;
}

/**
 * Renders a category badge.
 *
 * @param category - The category.
 * @param opts - The options.
 * @returns The badge HTML.
 */
export function defaultCategoryLinkRenderer(
  category: CategoryBadgeCategory,
  opts: CategoryBadgeOptions
): string {
  let restricted = get(category, "read_restricted");
  // `slugFor` reads only the id, the slug and the parent category.
  let url = opts.url
    ? opts.url
    : getURL(
        `/c/${Category.slugFor(category as Category)}/${get(category, "id")}`
      );
  let href = opts.link === false ? "" : url;
  let tagName = opts.link === false || opts.link === "false" ? "span" : "a";
  let extraClasses = opts.extraClasses ? " " + opts.extraClasses : "";
  let style = `${categoryVariables(category)}`;
  let html = "";
  let parentCategory: CategoryBadgeCategory | null | undefined = null;
  let categoryDir = "";
  let dataAttributes = category
    ? `data-category-id="${get(category, "id")}"`
    : "";

  if (!opts.hideParent) {
    parentCategory =
      get(category, "parentCategory") ||
      Category.findById(get(category, "parent_category_id"));
  }

  let siteSettings = helperContext().siteSettings as SiteSettingsService &
    BadgeSettings;

  let classNames = `badge-category`;
  if (restricted) {
    classNames += " restricted";
  }

  if (parentCategory) {
    classNames += ` --has-parent`;
    dataAttributes += ` data-parent-category-id="${parentCategory.id}"`;
  }

  if (opts.styleType) {
    classNames += ` --style-${opts.styleType}`;
  }

  html += `<span
    ${dataAttributes}
    data-drop-close="true"
    class="${classNames}"
    ${
      opts.previewColor
        ? `style="--category-badge-color: #${category.color}"`
        : ""
    }
  >`;

  if (opts.styleType === "icon" && opts.icon) {
    html += iconHTML(opts.icon);
  }

  if (opts.styleType === "emoji" && opts.emoji) {
    html += dEmoji(opts.emoji) ?? "";
  }

  // not ideal as we have to call it manually and we pass a fake category object
  // but there's not way around it for now
  let categoryName = applyValueTransformer(
    "category-display-name",
    escapeExpression(get(category, "name")),
    { category }
  );

  if (siteSettings.support_mixed_text_direction) {
    categoryDir = 'dir="auto"';
  }

  if (restricted) {
    html += iconHTML("category.restricted");
  }
  _extraIconRenderers.forEach((renderer) => {
    const iconName = renderer(category);
    if (iconName) {
      html += iconHTML(iconName);
    }
  });
  html += `<span class="badge-category__name" ${categoryDir}>${categoryName}</span>`;
  html += "</span>";

  if (opts.topicCount) {
    html += buildTopicCount(opts.topicCount);
  }

  if (opts.hasSubcategories) {
    html += `<span class="plus-subcategories">${i18n(
      "category_row.subcategories"
    )}</span>`;
  }

  if (opts.readOnly) {
    const desc = i18n("category_row.read_only");
    html += `<span class="read-only" aria-label="${desc}">${desc}</span>`;
  }

  if (href) {
    href = ` href="${href}" `;
  }

  return `<${tagName} class="badge-category__wrapper ${extraClasses}" ${
    style.length > 0 ? `style="${style}"` : ""
  } ${href}>${html}</${tagName}>`;
}
