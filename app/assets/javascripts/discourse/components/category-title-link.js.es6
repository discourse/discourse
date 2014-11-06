export default Em.Component.extend({
  tagName: 'h3',

  render: function(buffer) {
    var category = this.get('category'),
        logoUrl = category.get('logo_url');

    if (category.get('read_restricted')) {
      buffer.push("<i class='fa fa-group'></i> ");
    }

    buffer.push("<a href='" + Discourse.getURL('/c/') + Discourse.Category.slugFor(category) + "'>");

    var noLogo = Em.isEmpty(logoUrl);
    buffer.push(Handlebars.Utils.escapeExpression(category.get('name')));
    if (!noLogo) {
      buffer.push("<br><img src='" + logoUrl + "' class='category-logo'>");
    }
    buffer.push("</a>");
  }
});
