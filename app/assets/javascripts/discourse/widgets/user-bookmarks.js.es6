import { ajax } from 'discourse/lib/ajax';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import UserAction from 'discourse/models/user-action';

export default createWidget('user-bookmarks', {
  tagName: 'div.bookmarks',
  buildKey: () => 'user-bookmarks',

  defaultState() {
    return { loading: false, loaded: false, content: [] };
  },

  refreshBookmarks(state) {
    if (state.loading) { return; }

    const { currentUser } = this;

    state.loading = true;
    return ajax('/user_actions.json', {
      cache: 'false',
      data: {
        username: currentUser.username,
        filter: Discourse.UserAction.TYPES.bookmarks
      }
    }).then(result => {
      if (result && result.user_actions) {
        const copy = Em.A();
        let i = 0;
        result.user_actions.forEach(function(action) {
          if (++i > 5) {
            return;
          }
          action.title = Handlebars.Utils.escapeExpression(action.title);
          copy.pushObject(UserAction.create(action));
        });
        state.content.pushObjects(UserAction.collapseStream(copy));
      }
    }).finally(() => {
      state.loading = false;
      state.loaded = true;
      this.scheduleRerender();
    });
  },

  html(attrs, state) {
    if (!state.loaded) {
      this.refreshBookmarks(state);
    }

    if (state.loading) {
      return [ h('hr'), h('div.spinner-container', h('div.spinner')) ];
    }

    return [
      h('hr'),
      h('ul.menu-bookmarks', [
          state.content.map(bookmark => this.attach('user-menu-item', {
          href: bookmark.get('postUrl'),
          icon: 'bookmark',
          title: bookmark.title,
        })),
        this.attach('user-menu-item', {
          href: `${attrs.path}/activity/bookmarks`,
          title: I18n.t('user.more_bookmarks')
        })
      ]),
    ];
  },

});
