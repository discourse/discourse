import StringBuffer from 'discourse/mixins/string-buffer';

export default Ember.View.extend(StringBuffer, {
  tagName: 'button',
  classNames: ['btn', 'standard'],
  attributeBindings: ['title'],
  archived: Em.computed.alias('controller.model.message_archived'),
  archiving: Em.computed.alias('controller.model.archiving'),
  rerenderTriggers: ['archived', 'archiving'],

  title: function() {
    const key = this.get('archived') ? 'topic.move_to_inbox.help' : 'topic.archive_message.help';
    return I18n.t(key);
  }.property('archived'),

  renderString: function(buffer) {
    if (this.get('archived')){
      buffer.push(I18n.t('topic.move_to_inbox.title'));
    } else {
      buffer.push("<i class='fa fa-folder'></i>");
      buffer.push(I18n.t('topic.archive_message.title'));
    }
  },

  click: function() {
    if (!this.get('archiving')) {
      if (this.get('archived')) {
        this.get('controller').send('moveToInbox');
      } else {
        this.get('controller').send('archiveMessage');
      }
    }
  }
});

