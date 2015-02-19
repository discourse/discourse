export default Em.Component.extend({
  tagName: 'h3',

  render: function(buffer) {
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
