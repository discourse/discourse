import { createWidget } from 'discourse/widgets/widget';
import { iconNode } from 'discourse/helpers/fa-icon';
import { avatarImg } from 'discourse/widgets/post';
import DiscourseURL from 'discourse/lib/url';
import { wantsNewWindow } from 'discourse/lib/intercept-click';

import { h } from 'virtual-dom';

const dropdown = {
  buildClasses(attrs) {
    if (attrs.active) { return "active"; }
  },

  click(e) {
    if (wantsNewWindow(e)) { return; }
    e.preventDefault();
    if (!this.attrs.active) {
      this.sendWidgetAction(this.attrs.action);
    }
  }
};

createWidget('header-notifications', {
  html(attrs) {
    const { currentUser } = this;

    const contents = [ avatarImg('medium', { template: currentUser.get('avatar_template'),
                                             username: currentUser.get('username') }) ];

    const unreadNotifications = currentUser.get('unread_notifications');
    if (!!unreadNotifications) {
      contents.push(this.attach('link', { action: attrs.action,
                                          className: 'badge-notification unread-notifications',
                                          rawLabel: unreadNotifications }));
    }

    const unreadPMs = currentUser.get('unread_private_messages');
    if (!!unreadPMs) {
      contents.push(this.attach('link', { action: attrs.action,
                                          className: 'badge-notification unread-private-messages',
                                          rawLabel: unreadPMs }));
    }

    return contents;
  }
});

createWidget('user-dropdown', jQuery.extend({
  tagName: 'li.header-dropdown-toggle.current-user',

  buildId() {
    return 'current-user';
  },

  html(attrs) {
    const { currentUser } = this;

    return h('a.icon', { attributes: { href: currentUser.get('path'), 'data-auto-route': true } },
             this.attach('header-notifications', attrs));
  }
}, dropdown));

createWidget('header-dropdown', jQuery.extend({
  tagName: 'li.header-dropdown-toggle',

  html(attrs) {
    const title = I18n.t(attrs.title);

    const body = [iconNode(attrs.icon)];
    if (attrs.contents) {
      body.push(attrs.contents.call(this));
    }

    return h('a.icon', { attributes: { href: attrs.href,
                                       'data-auto-route': true,
                                       title,
                                       'aria-label': title,
                                       id: attrs.iconId } }, body);
  }
}, dropdown));

createWidget('header-icons', {
  tagName: 'ul.icons.clearfix',

  buildAttributes() {
    return { role: 'navigation' };
  },

  html(attrs) {
    const hamburger = this.attach('header-dropdown', {
                        title: 'hamburger_menu',
                        icon: 'bars',
                        iconId: 'toggle-hamburger-menu',
                        active: attrs.hamburgerVisible,
                        action: 'toggleHamburger',
                        contents() {
                          if (!attrs.flagCount) { return; }
                          return this.attach('link', {
                            href: '/admin/flags/active',
                            title: 'notifications.total_flagged',
                            rawLabel: attrs.flagCount,
                            className: 'badge-notification flagged-posts'
                          });
                        }
                      });

    const search = this.attach('header-dropdown', {
                     title: 'search.title',
                     icon: 'search',
                     iconId: 'search-button',
                     action: 'toggleSearchMenu',
                     active: attrs.searchVisible,
                     href: '/search'
                   });

    const icons = [search, hamburger];
    if (this.currentUser) {
      icons.push(this.attach('user-dropdown', { active: attrs.userVisible,
                                                action: 'toggleUserMenu' }));
    }

    return icons;
  },
});

createWidget('header-buttons', {
  tagName: 'span',

  html(attrs) {
    if (this.currentUser) { return; }

    const buttons = [];

    if (attrs.canSignUp && !attrs.topic) {
      buttons.push(this.attach('button', { label: "sign_up",
                                           className: 'btn-primary btn-small sign-up-button',
                                           action: "showCreateAccount" }));
    }


    buttons.push(this.attach('button', { label: 'log_in',
                                         className: 'btn-primary btn-small login-button',
                                         action: 'showLogin',
                                         icon: 'user' }));
    return buttons;
  }
});

export default createWidget('header', {
  tagName: 'header.d-header.clearfix',
  buildKey: () => `header`,

  defaultState() {
    return { searchVisible: false,
             hamburgerVisible: false,
             userVisible: false,
             contextEnabled: false };
  },

  html(attrs, state) {
    const panels = [this.attach('header-buttons', attrs),
                    this.attach('header-icons', { hamburgerVisible: state.hamburgerVisible,
                                                  userVisible: state.userVisible,
                                                  searchVisible: state.searchVisible,
                                                  flagCount: attrs.flagCount })];

    if (state.searchVisible) {
      panels.push(this.attach('search-menu', { contextEnabled: state.contextEnabled }));
    } else if (state.hamburgerVisible) {
      panels.push(this.attach('hamburger-menu'));
    } else if (state.userVisible) {
      panels.push(this.attach('user-menu'));
    }

    const contents = [ this.attach('home-logo', { minimized: !!attrs.topic }),
                       h('div.panel.clearfix', panels) ];

    if (attrs.topic) {
      contents.push(this.attach('header-topic-info', attrs));
    }

    return h('div.wrap', h('div.contents.clearfix', contents));
  },

  updateHighlight() {
    if (!this.state.searchVisible) {
      const service = this.container.lookup('search-service:main');
      service.set('highlightTerm', '');
    }
  },

  closeAll() {
    this.state.userVisible = false;
    this.state.hamburgerVisible = false;
    this.state.searchVisible = false;
  },

  linkClickedEvent() {
    this.closeAll();
    this.updateHighlight();
  },

  toggleSearchMenu() {
    if (this.site.mobileView) {
      const searchService = this.container.lookup('search-service:main');
      const context = searchService.get('searchContext');
      var params = "";

      if (context) {
        params = `?context=${context.type}&context_id=${context.id}&skip_context=true`;
      }

      return DiscourseURL.routeTo('/search' + params);
    }

    this.state.searchVisible = !this.state.searchVisible;
    this.updateHighlight();
    Ember.run.next(() => $('#search-term').focus());
  },

  toggleUserMenu() {
    this.state.userVisible = !this.state.userVisible;
  },

  toggleHamburger() {
    this.state.hamburgerVisible = !this.state.hamburgerVisible;
  },

  togglePageSearch() {
    const { state } = this;

    state.contextEnabled = false;

    const currentPath = this.container.lookup('controller:application').get('currentPath');
    const blacklist = [ /^discovery\.categories/ ];
    const whitelist = [ /^topic\./ ];
    const check = function(regex) { return !!currentPath.match(regex); };
    let showSearch = whitelist.any(check) && !blacklist.any(check);

    // If we're viewing a topic, only intercept search if there are cloaked posts
    if (showSearch && currentPath.match(/^topic\./)) {
      showSearch = ($('.topic-post .cooked, .small-action:not(.time-gap)').length <
                    this.container.lookup('controller:topic').get('model.postStream.stream.length'));
    }

    if (state.searchVisible) {
      this.toggleSearchMenu();
      return showSearch;
    }

    if (showSearch) {
      state.contextEnabled = true;
      this.toggleSearchMenu();
      return false;
    }

    return true;
  },

  searchMenuContextChanged(value) {
    this.state.contextEnabled = value;
  },

  domClean() {
    const { state } = this;

    if (state.searchVisible || state.hamburgerVisible || state.userVisible) {
      this.closeAll();
    }
  },

  headerKeyboardTrigger(msg) {
    switch(msg.type) {
      case 'search':
        this.toggleSearchMenu();
        break;
      case 'user':
        this.toggleUserMenu();
        break;
      case 'hamburger':
        this.toggleHamburger();
        break;
      case 'page-search':
        if (!this.togglePageSearch()) {
          msg.event.preventDefault();
          msg.event.stopPropagation();
        }
        break;
    }
  }

});
