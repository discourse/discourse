import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['star'],
  textKey: 'starred.title',
  helpKeyBinding: 'controller.starTooltipKey',
  attributeBindings: ['disabled'],

  rerenderTriggers: ['controller.starred'],

  click: function() {
    this.get('controller').send('toggleStar');
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-star " +
                 (this.get('controller.starred') ? ' starred' : '') +
                 "'></i>");
  }
});

