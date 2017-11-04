import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { formatUsername } from 'discourse/lib/utilities';

let extraGlyphs;

const PANEL_NOTIFICATIONS = 1;
const PANEL_BOOKMARKS = 2;
const PANEL_PRIVATE_MESSAGES = 3;

export function addUserMenuGlyph(glyph) {
  extraGlyphs = extraGlyphs || [];
  extraGlyphs.push(glyph);
}

createWidget('user-menu-links', {
  tagName: 'div.menu-links-header',

  html(attrs) {
    const { currentUser, siteSettings } = this;

    const isAnon = currentUser.is_anonymous;
    const allowAnon = siteSettings.allow_anonymous_posting &&
                      currentUser.trust_level >= siteSettings.anonymous_posting_min_trust_level ||
                      isAnon;

    const path = attrs.path;
    const glyphs = [];

    if (extraGlyphs) {
      extraGlyphs.forEach(g => {
        if (typeof g === "function") {
          g = g(this);
        }
        if (g) {
          glyphs.push(g);
        }
      });
    }

    glyphs.push({ label: 'user.bookmarks',
                      className: 'user-bookmarks-link' + (attrs.currentPanel === PANEL_BOOKMARKS ? ' selected' : ''),
                      icon: 'bookmark',
                      action: 'toggleUserBookmarks' });

    if (siteSettings.enable_private_messages) {
      glyphs.push({ label: 'user.private_messages',
                    className: 'user-pms-link' + (attrs.currentPanel === PANEL_PRIVATE_MESSAGES ? ' selected' : ''),
                    icon: 'envelope',
                    action: 'togglePrivateMessages' });
    }

    glyphs.push({ label: 'user.notifications',
                  className: 'user-notifications-link' + (attrs.currentPanel === PANEL_NOTIFICATIONS ? ' selected' : ''),
                  icon: 'bell',
                  action: 'toggleNotifications' });

    const profileLink = {
      route: 'user',
      model: currentUser,
      className: 'user-activity-link',
      icon: 'user',
      rawLabel: formatUsername(currentUser.username)
    };

    if (currentUser.is_anonymous) {
      profileLink.label = 'user.profile';
      profileLink.rawLabel = null;
    }

    const links = [profileLink];
    if (allowAnon) {
      if (!isAnon) {
        glyphs.push({ action: 'toggleAnonymous',
                      label: 'switch_to_anon',
                      className: 'enable-anonymous',
                      icon: 'user-secret' });
      } else {
        glyphs.push({ action: 'toggleAnonymous',
                      label: 'switch_from_anon',
                      className: 'disable-anonymous',
                      icon: 'ban' });
      }
    }

    // preferences always goes last
    glyphs.push({ label: 'user.preferences',
                  className: 'user-preferences-link',
                  icon: 'gear',
                  href: `${path}/preferences/account` });

    return h('ul.menu-links-row', [
             links.map(l => h('li', this.attach('link', l))),
             h('li.glyphs', glyphs.map(l => this.attach('link', $.extend(l, { hideLabel: true })))),
            ]);
  }
});

export default createWidget('user-menu', {
  tagName: 'div.user-menu',
  buildKey: () => 'user-menu',

  defaultState() {
    return {
      currentPanel: PANEL_NOTIFICATIONS,
    };
  },

  toggleUserBookmarks() {
    this.state.currentPanel = PANEL_BOOKMARKS;
  },

  togglePrivateMessages() {
    this.state.currentPanel = PANEL_PRIVATE_MESSAGES;
  },

  toggleNotifications() {
    this.state.currentPanel = PANEL_NOTIFICATIONS;
  },

  settings: {
    maxWidth: 300
  },

  panelContents() {
    const path = this.currentUser.get('path');

    const panels = [];
    panels.push(this.attach('user-menu-links', {
      path,
      currentPanel: this.state.currentPanel,
    }));

    if (this.state.currentPanel === PANEL_BOOKMARKS) {
      panels.push(this.attach('user-bookmarks', { path }));
    } else if (this.state.currentPanel === PANEL_PRIVATE_MESSAGES) {
      panels.push(this.attach('user-private-messages', { path }));
    } else {
      panels.push(this.attach('user-notifications', { path }));
    }

    panels.push(h('div.logout-link', [
      h('ul.menu-links',
        h('li', this.attach('link', { action: 'logout',
                                      className: 'logout',
                                      icon: 'sign-out',
                                      label: 'user.log_out' })))
      ]));

    return panels;
  },

  html() {
    return this.attach('menu-panel', {
      maxWidth: this.settings.maxWidth,
      contents: () => this.panelContents()
    });
  },

  clickOutside() {
    this.sendWidgetAction('toggleUserMenu');
  }
});
