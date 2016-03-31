import { iconHTML } from 'discourse/helpers/fa-icon';
import Combobox from 'discourse/components/combo-box';
import { on, observes } from 'ember-addons/ember-computed-decorators';

export default Combobox.extend({
  none: "topic.controls",

  @on('init')
  _createContent() {
    const content = [];
    const topic = this.get('topic');
    const details = topic.get('details');

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

    this.comboTemplate = (item) => {
      const contentItem = content.findProperty('id', item.id);
      if (!contentItem) { return item.text; }
      return `${iconHTML(contentItem.icon)}&nbsp; ${item.text}`;
    };

    this.set('content', content);
  },

  @observes('value')
  _valueChanged() {
    const value = this.get('value');
    const controller = this.get('parentView.controller');
    const topic = this.get('topic');

    const refresh = () => {
      this._createContent();
      this.set('value', null);
    };

    switch(value) {
      case 'invite':
        controller.send('showInvite');
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
        controller.send('showFlagTopic', topic);
        refresh();
        break;
    }
  }
});
