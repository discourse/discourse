import ButtonView from 'discourse/views/button';

export default ButtonView.extend({
  classNames: ['btn', 'btn-primary', 'create'],
  helpKey: 'topic.reply.help',

  text: function() {
    var archetypeCapitalized = this.get('controller.content.archetype').capitalize();
    var customTitle = this.get("parentView.replyButtonText" + archetypeCapitalized);
    if (customTitle) { return customTitle; }

    return I18n.t("topic.reply.title");
  }.property(),

  renderIcon: function(buffer) {
    buffer.push("<i class='fa fa-reply'></i>");
  },

  click: function() {
    this.get('controller').send('replyToPost');
  }
});

