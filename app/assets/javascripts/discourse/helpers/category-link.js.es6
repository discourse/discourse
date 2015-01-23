import registerUnbound from 'discourse/helpers/register-unbound';
import { iconHTML } from 'discourse/helpers/fa-icon';

var get = Em.get,
    escapeExpression = Handlebars.Utils.escapeExpression;

function categoryStripe(tagName, category, extraClasses, href) {
  if (!category) { return ""; }

  var color = Em.get(category, 'color'),
      style = color ? "style='background-color: #" + color + ";'" : "";

  return "<" + tagName + " class='badge-category-parent" + extraClasses + "' " + style + " href=\"" + href + "\"></" + tagName + ">";
}

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
      url = Discourse.getURL("/c/") + Discourse.Category.slugFor(category),
      href = (opts.link === false ? '' : url),
      tagName = (opts.link === false || opts.link === "false" ? 'span' : 'a'),
      extraClasses = (opts.extraClasses ? (' ' + opts.extraClasses) : '');

  var html = "";

  var parentCat = Discourse.Category.findById(get(category, 'parent_category_id'));
  if (opts.hideParent) { parentCat = null; }
  html += categoryStripe(tagName, parentCat, extraClasses, href);

  if (parentCat !== category) {
    html += categoryStripe(tagName, category, extraClasses, href);
  }

  var classNames = "badge-category clear-badge" + extraClasses;
  if (restricted) { classNames += " restricted"; }

  html += "<" + tagName + ' href="' + href + '" ' +
             'data-drop-close="true" class="' + classNames + '"' +
             (description ? 'title="' + escapeExpression(description) + '" ' : '') +
          ">";

  var name = escapeExpression(get(category, 'name'));
  if (restricted) {
    html += "<div>" + iconHTML('lock') + " " + name + "</div>";
  } else {
    html += name;
  }
  html += "</" + tagName + ">";

  return "<span class='badge-wrapper'>" + html + "</span>";
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
Ember.Handlebars.helper('bound-category-link', categoryLinkHTML);
