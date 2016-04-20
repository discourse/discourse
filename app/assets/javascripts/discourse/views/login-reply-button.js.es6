import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  textKey: 'topic.reply.title',
  classNames: ['btn', 'btn-primary', 'create'],
  click: function() {
    this.get('controller').send('showLogin');
  },
  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-reply'></i>");
  }
});
