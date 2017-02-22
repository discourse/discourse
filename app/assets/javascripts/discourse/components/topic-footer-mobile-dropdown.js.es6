import { iconHTML } from 'discourse-common/helpers/fa-icon';
import Combobox from 'discourse-common/components/combo-box';
import { observes } from 'ember-addons/ember-computed-decorators';

export default Combobox.extend({
  none: "topic.controls",

  init() {
    this._super();
    this._createContent();
  },

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
      const contentItem = content.findBy('id', item.id);
      if (!contentItem) { return item.text; }
      return `${iconHTML(contentItem.icon)}&nbsp; ${item.text}`;
    };

    this.set('content', content);
  },

  @observes('value')
  _valueChanged() {
    const value = this.get('value');
    const topic = this.get('topic');

    const refresh = () => {
      this._createContent();
      this.set('value', null);
    };

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
});
