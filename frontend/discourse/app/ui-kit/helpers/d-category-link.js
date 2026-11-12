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
import dEmoji from "discourse/ui-kit/helpers/d-emoji";
import { i18n } from "discourse-i18n";

/**
 * @typedef {Object} CategoryBadgeCategory
 * @property {number | string} [id]
 * @property {string} [name]
 * @property {string | null} [slug]
 * @property {string | null} [color]
 * @property {string | null} [textColor]
 * @property {string | null} [style_type]
 * @property {string | null} [icon]
 * @property {string | null} [emoji]
 * @property {boolean} [read_restricted]
 * @property {number | null} [parent_category_id]
 * @property {CategoryBadgeCategory | null} [parentCategory]
 */

/**
 * @typedef {Object} CategoryBadgeOptions
 * @property {String}  [url] The url that we want the category badge to link to.
 * @property {Boolean} [allowUncategorized] If false, returns an empty string for the uncategorized category.
 * @property {boolean | "false"} [link] If false, the category badge will not be a link.
 * @property {Boolean} [hideParent] If true, parent category will be hidden in the badge.
 * @property {Boolean} [previewColor] If true, category color will be set as an inline style.
 * @property {CategoryBadgeCategory[]} [ancestors] The ancestors of the category to generate the badge for.
 * @property {String}  [styleType] Badge style, either "icon", "emoji" or "square" (default).
 * @property {String}  [emoji] The emoji to use for the badge (if styleType is "emoji").
 * @property {String}  [icon] The icon to use for the badge (if styleType is "icon").
 * @property {string} [extraClasses] Additional wrapper classes.
 * @property {number} [topicCount] Topic count displayed after the badge.
 * @property {boolean} [hasSubcategories] Whether to display the subcategory indicator.
 * @property {boolean} [readOnly] Whether to display the read-only indicator.
 */

let _renderer = defaultCategoryLinkRenderer;

export function replaceCategoryLinkRenderer(fn) {
  _renderer = fn;
}

let _extraIconRenderers = [];

export function addExtraIconRenderer(renderer) {
  _extraIconRenderers.push(renderer);
}

/**
  Generates category badge HTML

  @param {CategoryBadgeCategory | null} [category] The category to generate the badge for.
  @param {CategoryBadgeOptions | null} [opts]
  @returns {string}
**/
export function categoryBadgeHTML(category, opts) {
  const { site, siteSettings } = helperContext();
  opts = opts || {};

  if (
    !category ||
    (!opts.allowUncategorized &&
      get(category, "id") === site.uncategorized_category_id &&
      siteSettings.suppress_uncategorized_badge)
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
    ["styleType", "icon", "emoji"].forEach((k) => delete newOpts[k]);

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

export function categoryLinkHTML(category, options) {
  let categoryOptions = {};

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

export default function dCategoryLink(...args) {
  return categoryLinkHTML(...args);
}

function buildTopicCount(count) {
  return `<span class="topic-count" aria-label="${i18n(
    "category_row.topic_count",
    { count }
  )}">&times; ${count}</span>`;
}

export function defaultCategoryLinkRenderer(category, opts) {
  let restricted = get(category, "read_restricted");
  let url = opts.url
    ? opts.url
    : getURL(`/c/${Category.slugFor(category)}/${get(category, "id")}`);
  let href = opts.link === false ? "" : url;
  let tagName = opts.link === false || opts.link === "false" ? "span" : "a";
  let extraClasses = opts.extraClasses ? " " + opts.extraClasses : "";
  let style = `${categoryVariables(category)}`;
  let html = "";
  let parentCategory = null;
  let categoryDir = "";
  let dataAttributes = category
    ? `data-category-id="${get(category, "id")}"`
    : "";

  if (!opts.hideParent) {
    parentCategory =
      get(category, "parentCategory") ||
      Category.findById(get(category, "parent_category_id"));
  }

  let siteSettings = helperContext().siteSettings;

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
