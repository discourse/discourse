import { registerUnbound } from 'discourse/lib/helpers';
import { iconHTML } from 'discourse/helpers/fa-icon';

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

  if ((!category) ||
        (!opts.allowUncategorized &&
         Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id") &&
         Discourse.SiteSettings.suppress_uncategorized_badge
        )
     ) return "";

  var description = get(category, 'description_text'),
      restricted = get(category, 'read_restricted'),
      url = opts.url ? opts.url : Discourse.getURL("/c/") + Discourse.Category.slugFor(category),
      href = (opts.link === false ? '' : url),
      tagName = (opts.link === false || opts.link === "false" ? 'span' : 'a'),
      extraClasses = (opts.extraClasses ? (' ' + opts.extraClasses) : ''),
      color = get(category, 'color'),
      html = "",
      parentCat = null;

  if (!opts.hideParent) {
    parentCat = Discourse.Category.findById(get(category, 'parent_category_id'));
  }

  if (parentCat && parentCat !== category) {
    html += categoryStripe(get(parentCat,'color'), "badge-category-parent-bg");
  }

  html += categoryStripe(color, "badge-category-bg");

  var classNames = "badge-category clear-badge";
  if (restricted) { classNames += " restricted"; }

  var textColor = "#" + get(category, 'text_color');

  html += "<span" + ' style="color: ' + textColor + ';" '+
             'data-drop-close="true" class="' + classNames + '"' +
             (description ? 'title="' + escapeExpression(description) + '" ' : '') +
          ">";

  var name = escapeExpression(get(category, 'name'));

  if (restricted) {
    html += iconHTML('lock') + " " + name;
  } else {
    html += name;
  }
  html += "</span>";

  if(href){
    href = " href='" + href + "' ";
  }

  extraClasses = Discourse.SiteSettings.category_style ? Discourse.SiteSettings.category_style + extraClasses : extraClasses;

  return "<" + tagName + " class='badge-wrapper " + extraClasses + "' " + href + ">" + html + "</" + tagName + ">";
}

export function categoryLinkHTML(category, options) {
  var categoryOptions = {};

  // TODO: This is a compatibility layer with the old helper structure.
  // Can be removed once we migrate to `registerUnbound` fully
  if (options && options.hash) { options = options.hash; }

  if (options) {
    if (options.allowUncategorized) { categoryOptions.allowUncategorized = true; }
    if (options.link !== undefined) { categoryOptions.link = options.link; }
    if (options.extraClasses) { categoryOptions.extraClasses = options.extraClasses; }
    if (options.hideParent) { categoryOptions.hideParent = true; }
  }
  return new Handlebars.SafeString(categoryBadgeHTML(category, categoryOptions));
}

registerUnbound('category-link', categoryLinkHTML);
