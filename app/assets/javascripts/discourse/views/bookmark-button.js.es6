import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['bookmark'],
  textKey: 'bookmarked.title',
  attributeBindings: ['disabled'],

  rerenderTriggers: ['controller.bookmarked'],

  helpKey: function() {
    return this.get("controller.bookmarked") ? "bookmarked.help.unbookmark" : "bookmarked.help.bookmark";
  }.property("controller.bookmarked"),

  click: function() {
    this.get('controller').send('toggleBookmark');
  },

  renderIcon: function(buffer) {
    var className = this.get("controller.bookmarked") ? "fa-bookmark" : "fa-bookmark-o";
    buffer.push("<i class='fa " + className + "'></i>");
  }
});
