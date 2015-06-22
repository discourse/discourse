import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.Component.extend(StringBuffer, {
  tagName: 'li',
  classNameBindings: ['active', 'content.hasIcon:has-icon'],
  attributeBindings: ['title'],
  hidden: Em.computed.not('content.visible'),
  rerenderTriggers: ['content.count'],

  title: function() {
    var categoryName = this.get('content.categoryName'),
        name = this.get('content.name'),
        extra = {};

    if (categoryName) {
      name = "category";
      extra.categoryName = categoryName;
    }
    return I18n.t("filters." + name.replace("/", ".") + ".help", extra);
  }.property("content.{categoryName,name}"),

  active: function() {
    return this.get('content.filterMode') === this.get('filterMode') ||
           this.get('filterMode').indexOf(this.get('content.filterMode')) === 0;
  }.property('content.filterMode', 'filterMode'),

  renderString(buffer) {
    const content = this.get('content');
    buffer.push("<a href='" + content.get('href') + "'>");
    if (content.get('hasIcon')) {
      buffer.push("<span class='" + content.get('name') + "'></span>");
    }
    buffer.push(this.get('content.displayName'));
    buffer.push("</a>");
  }
});
