import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { formatUsername } from 'discourse/lib/utilities';
import { ajax } from 'discourse/lib/ajax';

let extraGlyphs;

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
                      className: 'user-bookmarks-link',
                      icon: 'bookmark',
                      href: `${path}/activity/bookmarks` });

    if (siteSettings.enable_private_messages) {
      glyphs.push({ label: 'user.private_messages',
                    className: 'user-pms-link',
                    icon: 'envelope',
                    href: `${path}/messages` });
    }

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

createWidget('user-menu-dismiss-link', {
  tagName: 'div.dismiss-link',
  buildKey: () => 'user-menu-dismiss-link',

  html() {
    if (userNotifications.state.notifications.filterBy("read", false).length > 0) {
      return h('ul.menu-links',
        h('li',
          this.attach('link', {
            action: 'dismissNotifications',
            className: 'dismiss',
            icon: 'check',
            label: 'user.dismiss',
            title: 'user.dismiss_notifications_tooltip'
          })
        )
      );
    } else {
      return '';
    }
  },

  dismissNotifications() {
    ajax('/notifications/mark-read', { method: 'PUT' }).then(() => {
      userNotifications.notificationsChanged();
    });
  }
});

let userNotifications = null,
  dismissLink = null;

export default createWidget('user-menu', {
  tagName: 'div.user-menu',

  settings: {
    maxWidth: 300
  },

  panelContents() {
    const path = this.currentUser.get('path');
    userNotifications = this.attach('user-notifications', { path });
    dismissLink = this.attach('user-menu-dismiss-link');

    return [
      this.attach('user-menu-links', { path }),
      userNotifications,
      h('div.logout-link', [
        h('ul.menu-links',
          h('li',
            this.attach('link', {
              action: 'logout',
              className: 'logout',
              icon: 'sign-out',
              label: 'user.log_out'
            })
          )
        )
      ]),
      dismissLink
    ];
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
