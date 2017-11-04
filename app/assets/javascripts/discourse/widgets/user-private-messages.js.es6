import { ajax } from 'discourse/lib/ajax';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import Topic from 'discourse/models/topic';

export default createWidget('user-private-messages', {
  tagName: 'div.private-messages',
  buildKey: () => 'user-private-messages',

  defaultState() {
    return { loading: false, loaded: false, content: [] };
  },

  refreshPrivateMessages(state) {
    if (state.loading) { return; }

    const { currentUser } = this;

    state.loading = true;
    return ajax('/topics/private-messages/' + currentUser.username + '.json', {cache: 'false'}).then(result => {
      if (result && result.topic_list && result.topic_list.topics) {
        let i = 0;
        result.topic_list.topics.forEach(function(topic) {
          if (++i > 5) {
            return;
          }
          topic.title = Handlebars.Utils.escapeExpression(topic.title);
          state.content.pushObject(Topic.create(topic));
        });
      }
    }).finally(() => {
      state.loading = false;
      state.loaded = true;
      this.scheduleRerender();
    });
  },

  html(attrs, state) {
    if (!state.loaded) {
      this.refreshPrivateMessages(state);
    }

    if (state.loading) {
      return [ h('hr'), h('div.spinner-container', h('div.spinner')) ];
    }

    return [
      h('hr'),
      h('ul.menu-private-messages', [
          state.content.map(pm => this.attach('user-menu-item', {
          href: pm.get('lastUnreadUrl'),
          icon: 'envelope',
          title: pm.title,
        })),
        this.attach('user-menu-item', {
          href: `${attrs.path}/messages`,
          title: I18n.t('user.more_pms'),
        })
      ]),
    ];
  },

});
