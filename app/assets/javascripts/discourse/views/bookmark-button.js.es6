import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['bookmark'],
  attributeBindings: ['disabled'],

  textKey: function() {
    return this.get('controller.bookmarked') ? 'bookmarked.clear_bookmarks' : 'bookmarked.title';
  }.property('controller.bookmarked'),

  rerenderTriggers: ['controller.bookmarked'],

  helpKey: function() {
    return this.get("controller.bookmarked") ? "bookmarked.help.unbookmark" : "bookmarked.help.bookmark";
  }.property("controller.bookmarked"),

  click: function() {
    this.get('controller').send('toggleBookmark');
  },

  renderIcon: function(buffer) {
    var className = this.get("controller.bookmarked") ? "bookmarked" : "";
    buffer.push("<i class='fa fa-bookmark " + className + "'></i>");
  }
});
