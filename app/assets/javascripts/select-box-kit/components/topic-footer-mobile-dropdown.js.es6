import computed from 'ember-addons/ember-computed-decorators';
import ComboBoxComponent from 'select-box-kit/components/combo-box';

export default ComboBoxComponent.extend({
  headerText: I18n.t('topic.controls'),
  classNames: "topic-footer-mobile-dropdown",

  @computed("topic", "topic.details", "value")
  content(topic, details) {
    const content = [];

    if (details.get('can_invite_to')) {
      content.push({ id: 'invite', icon: 'users', name: I18n.t('topic.invite_reply.title') });
    }

    if (topic.get('bookmarked')) {
      content.push({ id: 'bookmark', icon: 'bookmark', name: I18n.t('bookmarked.clear_bookmarks') });
    } else {
      content.push({ id: 'bookmark', icon: 'bookmark', name: I18n.t('bookmarked.title') });
    }

    content.push({ id: 'share', icon: 'link', name: I18n.t('topic.share.title') });

    if (details.get('can_flag_topic')) {
      content.push({ id: 'flag', icon: 'flag', name: I18n.t('topic.flag_topic.title') });
    }

    return content;
  },

  actions: {
    onSelect(value) {
      this.defaultOnSelect();

      const topic = this.get('topic');

      // In case it's not a valid topic
      if (!topic.get('id')) {
        return;
      }

      const refresh = () => this.set('value', null);

      switch(value) {
        case 'invite':
          this.attrs.showInvite();
          refresh();
          break;
        case 'bookmark':
          topic.toggleBookmark().then(() => refresh());
          break;
        case 'share':
          this.appEvents.trigger('share:url', topic.get('shareUrl'), $('#topic-footer-buttons'));
          refresh();
          break;
        case 'flag':
          this.attrs.showFlagTopic();
          refresh();
          break;
      }
    }
  }
});
