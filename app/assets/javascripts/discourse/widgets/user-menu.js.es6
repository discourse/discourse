import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';

createWidget('user-menu-links', {
  tagName: 'div.menu-links-header',

  html(attrs) {
    const { currentUser, siteSettings } = this;

    const isAnon = currentUser.is_anonymous;
    const allowAnon = siteSettings.allow_anonymous_posting &&
                      currentUser.trust_level >= siteSettings.anonymous_posting_min_trust_level ||
                      isAnon;

    const path = attrs.path;
    const glyphs = [{ label: 'user.bookmarks',
                      className: 'user-bookmarks-link',
                      icon: 'bookmark',
                      href: `${path}/activity/bookmarks` }];

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
      rawLabel: currentUser.username
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
        links.push({ className: 'disable-anonymous',
                     action: 'toggleAnonymous',
                     label: 'switch_from_anon' });
      }
    }

    // preferences always goes last
    glyphs.push({ label: 'user.preferences',
                  className: 'user-preferences-link',
                  icon: 'gear',
                  href: `${path}/preferences` });

    return h('ul.menu-links-row', [
             links.map(l => h('li', this.attach('link', l))),
             h('li.glyphs', glyphs.map(l => this.attach('link', $.extend(l, { hideLabel: true })))),
            ]);
  }
});

export default createWidget('user-menu', {
  tagName: 'div.user-menu',

  panelContents() {
    const path = this.currentUser.get('path');

    return [this.attach('user-menu-links', { path }),
            this.attach('user-notifications', { path }),
            h('div.logout-link', [
              h('hr'),
              h('ul.menu-links',
                h('li', this.attach('link', { action: 'logout',
                                                       className: 'logout',
                                                       icon: 'sign-out',
                                                       label: 'user.log_out' })))
              ])];
  },

  html() {
    return this.attach('menu-panel', { contents: () => this.panelContents() });
  },

  clickOutside() {
    this.sendWidgetAction('toggleUserMenu');
  }
});
