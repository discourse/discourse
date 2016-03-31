import { iconHTML } from 'discourse/helpers/fa-icon';

export default Em.Component.extend({
  tagName: 'h3',

  render(buffer) {
    const category = this.get('category');
    const categoryUrl = Discourse.getURL('/c/') + Discourse.Category.slugFor(category);
    const categoryName = Handlebars.Utils.escapeExpression(category.get('name'));

    if (category.get('read_restricted')) { buffer.push(iconHTML('lock')); }

    buffer.push(`<a href='${categoryUrl}'>`);
    buffer.push(`<span class='category-name'>${categoryName}</span>`);
    buffer.push(`</a>`);
  }
});
