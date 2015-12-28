export default Em.Component.extend({
  tagName: 'a',
  attributeBindings: ['href'],
  href: function() {
    return Discourse.getURL('/c/') + Discourse.Category.slugFor(this.get('category'));
  }.property(),

  render(buffer) {
    const category = this.get('category');
    const categoryLogo = category.get('logo_url');
    buffer.push(`<img class="category-logo" src='${categoryLogo}'/>`);
  }
});