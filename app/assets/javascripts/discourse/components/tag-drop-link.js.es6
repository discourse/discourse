import DiscourseURL from 'discourse/lib/url';

export default Ember.Component.extend({
  tagName: 'a',
  classNameBindings: [':tag-badge-wrapper', ':badge-wrapper', ':bullet', 'tagClass'],
  attributeBindings: ['href'],

  href: function() {
    var url = '/tags';
    if (this.get('category')) {
      url += this.get('category.url');
    }
    return url + '/' + this.get('tagId');
  }.property('tagId', 'category'),

  tagClass: function() {
    return "tag-" + this.get('tagId');
  }.property('tagId'),

  render(buffer) {
    buffer.push(Handlebars.Utils.escapeExpression(this.get('tagId')));
  },

  click(e) {
    e.preventDefault();
    DiscourseURL.routeTo(this.get('href'));
    return true;
  }
});
