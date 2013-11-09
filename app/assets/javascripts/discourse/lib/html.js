/**
  Helpers to build HTML strings such as rich links to categories and topics.

  @class HTML
  @namespace Discourse
  @module Discourse
**/
Discourse.HTML = {

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
    Create a badge-like category link

    @method categoryLink
    @param {Discourse.Category} category the category whose link we want
    @param {Object} opts The options for the category link
      @param {Boolean} opts.allowUncategorized Whether we allow rendering of the uncategorized category
    @returns {String} the html category badge
  **/
  categoryLink: function(category, opts) {
    opts = opts || {};

    if ((!category) ||
        (!opts.allowUncategorized && Em.get(category, 'id') === Discourse.Site.currentProp("uncategorized_category_id"))) return "";

    var name = Em.get(category, 'name'),
        description = Em.get(category, 'description'),
        html = "<a href=\"" + Discourse.getURL("/category/") + Discourse.Category.slugFor(category) + "\" class=\"badge-category\" ";

    // Add description if we have it
    if (description) html += "title=\"" + Handlebars.Utils.escapeExpression(description) + "\" ";

    var categoryStyle = Discourse.HTML.categoryStyle(category);
    if (categoryStyle) {
      html += "style=\"" + categoryStyle + "\" ";
    }
    html += ">" + name + "</a>";

    return html;
  }

};