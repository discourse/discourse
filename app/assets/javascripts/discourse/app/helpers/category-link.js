import { get } from "@ember/object";
import { htmlSafe } from "@ember/template";
import categoryVariables from "discourse/helpers/category-variables";
import replaceEmoji from "discourse/helpers/replace-emoji";
import getURL from "discourse/lib/get-url";
import { helperContext } from "discourse/lib/helpers";
import { iconHTML } from "discourse/lib/icon-library";
import { applyValueTransformer } from "discourse/lib/transformer";
import { escapeExpression } from "discourse/lib/utilities";
import Category from "discourse/models/category";
import { i18n } from "discourse-i18n";

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

  @param {Object} category The category to generate the badge for.
  @param {Object} opts
    @param {String}  [opts.url] The url that we want the category badge to link to.
    @param {Boolean} [opts.allowUncategorized] If false, returns an empty string for the uncategorized category.
    @param {Boolean} [opts.link] If false, the category badge will not be a link.
    @param {Boolean} [opts.hideParent] If true, parent category will be hidden in the badge.
    @param {Boolean} [opts.recursive] If true, the function will be called recursively for all parent categories
    @param {Number}  [opts.depth] Current category depth, used for limiting recursive calls
    @param {Boolean} [opts.previewColor] If true, category color will be set as an inline style.
    @param {Array}   [opts.ancestors] The ancestors of the category to generate the badge for.
    @param {String}  [opts.styleType] Badge style, either "icon", "emoji" or "square" (default).
    @param {String}  [opts.emoji] The emoji to use for the badge (if styleType is "emoji").
    @param {String}  [opts.icon] The icon to use for the badge (if styleType is "icon").
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
    opts.styleType = category.style_type || "square";

    if (opts.styleType === "icon") {
      opts.icon = opts.icon || category.icon;
    } else if (opts.styleType === "emoji") {
      opts.emoji = opts.emoji || category.emoji;
    }
  }

  const depth = (opts.depth || 1) + 1;
  if (opts.ancestors) {
    const { ancestors, ...otherOpts } = opts;

    // allow each ancestor to use its own styles
    ["styleType", "icon", "emoji"].forEach((k) => delete otherOpts[k]);

    return [category, ...ancestors]
      .reverse()
      .map((c) => {
        return categoryBadgeHTML(c, { ...otherOpts });
      })
      .join("");
  } else if (opts.recursive && depth <= siteSettings.max_category_nesting) {
    const parentCategory = Category.findById(category.parent_category_id);
    const lastSubcategory = !opts.depth;
    opts.depth = depth;
    const parentBadges = categoryBadgeHTML(parentCategory, opts);
    opts.lastSubcategory = lastSubcategory;
    return parentBadges + _renderer(category, opts);
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
    if (options.recursive) {
      categoryOptions.recursive = true;
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
  return htmlSafe(categoryBadgeHTML(category, categoryOptions));
}

export default categoryLinkHTML;

function buildTopicCount(count) {
  return `<span class="topic-count" aria-label="${i18n(
    "category_row.topic_count",
    { count }
  )}">&times; ${count}</span>`;
}

export function defaultCategoryLinkRenderer(category, opts) {
  // not ideal as we have to call it manually and we pass a fake category object
  // but there's not way around it for now
  let descriptionText = applyValueTransformer(
    "category-description-text",
    escapeExpression(get(category, "description_text")),
    { category }
  );
  let restricted = get(category, "read_restricted");
  let url = opts.url
    ? opts.url
    : getURL(`/c/${Category.slugFor(category)}/${get(category, "id")}`);
  let href = opts.link === false ? "" : url;
  let tagName = opts.link === false || opts.link === "false" ? "span" : "a";
  let extraClasses = opts.extraClasses ? " " + opts.extraClasses : "";
  let style = `${categoryVariables(category)}`;
  let html = "";
  let parentCat = null;
  let categoryDir = "";
  let dataAttributes = category
    ? `data-category-id="${get(category, "id")}"`
    : "";

  if (!opts.hideParent) {
    parentCat = Category.findById(get(category, "parent_category_id"));
  }

  let siteSettings = helperContext().siteSettings;

  let classNames = `badge-category`;
  if (restricted) {
    classNames += " restricted";
  }

  if (parentCat) {
    classNames += ` --has-parent`;
    dataAttributes += ` data-parent-category-id="${parentCat.id}"`;
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
    ${descriptionText ? 'title="' + descriptionText + '" ' : ""}
  >`;

  if (opts.styleType === "icon" && opts.icon) {
    html += iconHTML(opts.icon);
  }

  if (opts.styleType === "emoji" && opts.emoji) {
    html += replaceEmoji(`:${opts.emoji}:`);
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

  if (opts.subcategoryCount) {
    html += `<span class="plus-subcategories">${i18n(
      "category_row.subcategory_count",
      { count: opts.subcategoryCount }
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
