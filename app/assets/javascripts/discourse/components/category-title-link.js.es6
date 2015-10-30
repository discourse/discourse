export default Em.Component.extend({
  tagName: 'h3',

  render: function(buffer) {
    // SP - START - Pill style category titles
    var category = this.get('category'),
        logoUrl = category.get('logo_url'),
        categoryUrl = Discourse.getURL('/c/') + Discourse.Category.slugFor(category),
        categoryName = Handlebars.Utils.escapeExpression(category.get('name')),
        bg_color = category.color,
        text_color = category.get("text_color");

    /* Note
    *
    *  You Should be able to remove this SitePoint modifcation by removing
    *  the lines inclusively from [SP - START] to [SP - END]
    *
    *  1 - Anchor tag with pill class (category-name) and background and foreground colors
    *  2 - Add the lock icon if the category is read restricted
    *  3 - Add in the category Name
    *  4 - Apparently there are category logos or something, i dunno
    *  5 - Close it all up
    */

    /* 1 */ buffer.push("<a class='category-name' href='"+ categoryUrl +"' style='background:#"+ bg_color +"; color:#"+ text_color +";'>")
    /* 2 */ if (category.get('read_restricted')) { buffer.push("<i class='fa fa-lock'></i>"); }
    /* 3 */ buffer.push("<span class='category-name-text'>" + categoryName + "</span>");
    /* 4 */ if (!Em.isEmpty(logoUrl)) { buffer.push("<img src='" + logoUrl + "' class='category-logo'>"); }
    /* 5 */ buffer.push("</a>");
  },

  old_render: function(buffer) {
    // SP - END
    var category = this.get('category'),
        logoUrl = category.get('logo_url'),
        categoryUrl = Discourse.getURL('/c/') + Discourse.Category.slugFor(category),
        categoryName = Handlebars.Utils.escapeExpression(category.get('name'));

    if (category.get('read_restricted')) { buffer.push("<i class='fa fa-lock'></i>"); }

    buffer.push("<a href='" + categoryUrl + "'>");
    buffer.push("<span class='category-name'>" + categoryName + "</span>");

    if (!Em.isEmpty(logoUrl)) { buffer.push("<img src='" + logoUrl + "' class='category-logo'>"); }

    buffer.push("</a>");
  }
});
