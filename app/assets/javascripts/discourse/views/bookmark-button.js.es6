import ButtonView from 'discourse/views/button';
import { iconHTML } from 'discourse/helpers/fa-icon';

export default ButtonView.extend({
  classNames: ['bookmark'],
  attributeBindings: ['disabled'],

  bookmarked: Ember.computed.alias('controller.model.bookmarked'),

  textKey: function() {
    return this.get('bookmarked') ? 'bookmarked.clear_bookmarks' : 'bookmarked.title';
  }.property('bookmarked'),

  rerenderTriggers: ['bookmarked'],

  helpKey: function() {
    return this.get("bookmarked") ? "bookmarked.help.unbookmark" : "bookmarked.help.bookmark";
  }.property("bookmarked"),

  click() {
    this.get('controller').send('toggleBookmark');
  },

  renderIcon(buffer) {
    const className = this.get("bookmarked") ? "bookmarked" : "";
    buffer.push(iconHTML('bookmark', { class: className }));
  }
});
