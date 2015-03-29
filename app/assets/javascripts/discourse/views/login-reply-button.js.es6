import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  textKey: 'topic.login_reply',
  classNames: ['btn', 'btn-primary', 'create'],
  click: function() {
    this.get('controller').send('showLogin');
  },
  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-user'></i>");
  }
});
