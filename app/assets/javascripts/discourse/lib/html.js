/**
  Helpers to build HTML strings as well as custom fragments.

  @class HTML
  @namespace Discourse
  @module Discourse
**/

var customizations = {};

Discourse.HTML = {

  /**
    Return a custom fragment of HTML by key. It can be registered via a plugin
    using `setCustomHTML(key, html)`. This is used by a handlebars helper to find
    the HTML content it wants. It will also check the `PreloadStore` for any server
    side preloaded HTML.

    @method getCustomHTML
    @param {String} key to lookup
  **/
  getCustomHTML: function(key) {
    var c = customizations[key];
    if (c) {
      return new Handlebars.SafeString(c);
    }

    var html = PreloadStore.get("customHTML");
    if (html && html[key] && html[key].length) {
      return new Handlebars.SafeString(html[key]);
    }
  },

  /**
    Set a fragment of HTML by key. It can then be looked up with `getCustomHTML(key)`.

    @method setCustomHTML
    @param {String} key to store the html
    @param {String} html fragment to store
  **/
  setCustomHTML: function(key, html) {
    customizations[key] = html;
  },

  /**
    Returns the CSS styles for a category

    @method categoryStyle
    @param {Discourse.Category} category the category whose link we want
  **/
  categoryStyle: function(category) {
    var color = Em.get(category, 'color'),
        textColor = Em.get(category, 'text_color');

    if (!color && !textColor) { return; }

    // Add the custom style if we need to
    var style = "";
    if (color) { style += "background-color: #" + color + "; "; }
    if (textColor) { style += "color: #" + textColor + "; "; }
    return style;
  },

  /**
    Create a category badge

    @method categoryBadge
    @param {Discourse.Category} category the category whose link we want
    @param {Object} opts The options for the category link
      @param {Boolean} opts.allowUncategorized Whether we allow rendering of the uncategorized category (default false)
      @param {Boolean} opts.showParent Whether to visually show whether category is a sub-category (default false)
      @param {Boolean} opts.link Whether this category badge should link to the category (default true)
      @param {String}  opts.extraClasses add this string to the class attribute of the badge
    @returns {String} the html category badge
  **/
  categoryBadge: function(category, opts) {
    opts = opts || {};

    if ((!category) ||
          (!opts.allowUncategorized &&
           Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id") &&
           Discourse.SiteSettings.suppress_uncategorized_badge
          )
       ) return "";

    var name = Em.get(category, 'name'),
        description = Em.get(category, 'description_text'),
        restricted = Em.get(category, 'read_restricted'),
        url = Discourse.getURL("/c/") + Discourse.Category.slugFor(category),
        elem = (opts.link === false ? 'span' : 'a'),
        extraClasses = (opts.extraClasses ? (' ' + opts.extraClasses) : ''),
        html = "<" + elem + " href=\"" + (opts.link === false ? '' : url) + "\" ",
        categoryStyle;

    // Parent stripe implies onlyStripe
    if (opts.onlyStripe) { opts.showParent = true; }

    html += "data-drop-close=\"true\" class=\"badge-category" + (restricted ? ' restricted' : '' ) +
            (opts.onlyStripe ? ' clear-badge' : '') +
            extraClasses + "\" ";
    name = Handlebars.Utils.escapeExpression(name);

    // Add description if we have it, without tags. Server has sanitized the description value.
    if (description) html += "title=\"" + Handlebars.Utils.escapeExpression(description) + "\" ";

    if (!opts.onlyStripe) {
      categoryStyle = Discourse.HTML.categoryStyle(category);
      if (categoryStyle) {
        html += "style=\"" + categoryStyle + "\" ";
      }
    }

    if (restricted) {
      html += "><div><i class='fa fa-group'></i> " + name + "</div></" + elem + ">";
    } else {
      html += ">" + name + "</" + elem + ">";
    }

    if (opts.onlyStripe || (opts.showParent && category.get('parent_category_id'))) {
      var parent = Discourse.Category.findById(category.get('parent_category_id'));
      if (!parent) { parent = category; }

      categoryStyle = Discourse.HTML.categoryStyle(opts.onlyStripe ? category : parent) || '';
      html = "<span class='badge-wrapper'><" + elem + " class='badge-category-parent" + extraClasses + "' style=\"" + categoryStyle + 
             "\" href=\"" + (opts.link === false ? '' : url) + "\"><span class='category-name'>" +
             (Em.get(parent, 'read_restricted') ? "<i class='fa fa-group'></i> " : "") +
             Em.get(parent, 'name') + "</span></" + elem + ">" +
             html + "</span>";
    }

    return html;
  }

};
