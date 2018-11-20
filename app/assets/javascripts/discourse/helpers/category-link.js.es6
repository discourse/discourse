import { registerUnbound } from "discourse-common/lib/helpers";
import { isRTL } from "discourse/lib/text-direction";
import { iconHTML } from "discourse-common/lib/icon-library";

var get = Em.get,
  escapeExpression = Handlebars.Utils.escapeExpression;

function categoryStripe(color, classes) {
  var style = color ? "style='background-color: #" + color + ";'" : "";
  return "<span class='" + classes + "' " + style + "></span>";
}

/**
  Generates category badge HTML

  @param {Object} category The category to generate the badge for.
  @param {Object} opts
    @param {String}  [opts.url] The url that we want the category badge to link to.
    @param {Boolean} [opts.allowUncategorized] If false, returns an empty string for the uncategorized category.
    @param {Boolean} [opts.link] If false, the category badge will not be a link.
    @param {Boolean} [opts.hideParaent] If true, parent category will be hidden in the badge.
**/
export function categoryBadgeHTML(category, opts) {
  opts = opts || {};

  if (
    !category ||
    (!opts.allowUncategorized &&
      Ember.get(category, "id") ===
        Discourse.Site.currentProp("uncategorized_category_id") &&
      Discourse.SiteSettings.suppress_uncategorized_badge)
  )
    return "";

  let description = get(category, "description_text");
  let restricted = get(category, "read_restricted");
  let url = opts.url
    ? opts.url
    : Discourse.getURL("/c/") + Discourse.Category.slugFor(category);
  let href = opts.link === false ? "" : url;
  let tagName = opts.link === false || opts.link === "false" ? "span" : "a";
  let extraClasses = opts.extraClasses ? " " + opts.extraClasses : "";
  let color = get(category, "color");
  let html = "";
  let parentCat = null;
  let categoryDir = "";

  if (!opts.hideParent) {
    parentCat = Discourse.Category.findById(
      get(category, "parent_category_id")
    );
  }

  const categoryStyle =
    opts.categoryStyle || Discourse.SiteSettings.category_style;
  if (categoryStyle !== "none") {
    if (parentCat && parentCat !== category) {
      html += categoryStripe(
        get(parentCat, "color"),
        "badge-category-parent-bg"
      );
    }
    html += categoryStripe(color, "badge-category-bg");
  }

  let classNames = "badge-category clear-badge";
  if (restricted) {
    classNames += " restricted";
  }

  let style = "";
  if (categoryStyle === "box") {
    style = `style="color: #${get(category, "text_color")};"`;
  }

  html +=
    `<span ${style} ` +
    'data-drop-close="true" class="' +
    classNames +
    '"' +
    (description ? 'title="' + escapeExpression(description) + '" ' : "") +
    ">";

  let categoryName = escapeExpression(get(category, "name"));

  if (Discourse.SiteSettings.support_mixed_text_direction) {
    categoryDir = isRTL(categoryName) ? 'dir="rtl"' : 'dir="ltr"';
  }

  if (restricted) {
    html += `${iconHTML(
      "lock"
    )}<span class="category-name" ${categoryDir}>${categoryName}</span>`;
  } else {
    html += `<span class="category-name" ${categoryDir}>${categoryName}</span>`;
  }
  html += "</span>";

  if (href) {
    href = ` href="${href}" `;
  }

  extraClasses = categoryStyle ? categoryStyle + extraClasses : extraClasses;
  return `<${tagName} class="badge-wrapper ${extraClasses}" ${href}>${html}</${tagName}>`;
}

export function categoryLinkHTML(category, options) {
  var categoryOptions = {};

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
    if (options.extraClasses) {
      categoryOptions.extraClasses = options.extraClasses;
    }
    if (options.hideParent) {
      categoryOptions.hideParent = true;
    }
    if (options.categoryStyle) {
      categoryOptions.categoryStyle = options.categoryStyle;
    }
  }
  return new Handlebars.SafeString(
    categoryBadgeHTML(category, categoryOptions)
  );
}

registerUnbound("category-link", categoryLinkHTML);
