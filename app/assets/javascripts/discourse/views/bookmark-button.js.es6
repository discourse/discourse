import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['bookmark'],
  textKey: 'bookmarked.title',
  helpKeyBinding: 'controller.bookmarkTooltipKey',
  attributeBindings: ['disabled'],

  rerenderTriggers: ['controller.bookmarked'],

  click: function() {
    this.get('controller').send('toggleBookmark');
  },

  renderIcon: function(buffer) {
    var className = this.get("controller.bookmarked") ? "fa-bookmark" : "fa-bookmark-o";
    buffer.push("<i class='fa " + className + "'></i>");
  }
});
