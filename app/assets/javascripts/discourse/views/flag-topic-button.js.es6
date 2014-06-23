import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['flag-topic'],
  textKey: 'topic.flag_topic.title',
  helpKey: 'topic.flag_topic.help',

  click: function() {
    this.get('controller').send('showFlagTopic', this.get('controller.content'));
  },

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-flag'></i>");
  }
});
