import ButtonView from 'discourse/views/button';

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

  click: function() {
    this.get('controller').send('toggleBookmark');
  },

  renderIcon: function(buffer) {
    var className = this.get("bookmarked") ? "bookmarked" : "";
    buffer.push("<i class='fa fa-bookmark " + className + "'></i>");
  }
});
