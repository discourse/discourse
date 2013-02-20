(function() {

  window.Discourse.NavItemView = Ember.View.extend({
    tagName: 'li',
    classNameBindings: ['isActive', 'content.hasIcon:has-icon'],
    attributeBindings: ['title'],
    title: (function() {
      var categoryName, extra, name;
      name = this.get('content.name');
      categoryName = this.get('content.categoryName');
      if (categoryName) {
        extra = {
          categoryName: categoryName
        };
        name = "category";
      }
      return Ember.String.i18n("filters." + name + ".help", extra);
    }).property("content.filter"),
    isActive: (function() {
      if (this.get("content.name") === this.get("controller.filterMode")) {
        return "active";
      }
      return "";
    }).property("content.name", "controller.filterMode"),
    hidden: (function() {
      return !this.get('content.visible');
    }).property('content.visible'),
    name: (function() {
      var categoryName, extra, name;
      name = this.get('content.name');
      categoryName = this.get('content.categoryName');
      extra = {
        count: this.get('content.count') || 0
      };
      if (categoryName) {
        name = 'category';
        extra.categoryName = categoryName.capitalize();
      }
      return I18n.t("js.filters." + name + ".title", extra);
    }).property('count'),
    render: function(buffer) {
      var content;
      content = this.get('content');
      buffer.push("<a href='" + (content.get('href')) + "'>");
      if (content.get('hasIcon')) {
        buffer.push("<span class='" + (content.get('name')) + "'></span>");
      }
      buffer.push(this.get('name'));
      return buffer.push("</a>");
    }
  });

}).call(this);
