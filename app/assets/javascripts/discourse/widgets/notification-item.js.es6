import { wantsNewWindow } from 'discourse/lib/intercept-click';
import RawHtml from 'discourse/widgets/raw-html';
import { createWidget } from 'discourse/widgets/widget';
import DiscourseURL from 'discourse/lib/url';
import { h } from 'virtual-dom';
import { emojiUnescape } from 'discourse/lib/text';
import { postUrl, escapeExpression } from 'discourse/lib/utilities';
import { setTransientHeader } from 'discourse/lib/ajax';

const LIKED_TYPE = 5;
const INVITED_TYPE = 8;
const GROUP_SUMMARY_TYPE = 16;

createWidget('notification-item', {
  tagName: 'li',

  buildClasses(attrs) {
    const classNames = [];
    if (attrs.get('read')) { classNames.push('read'); }
    if (attrs.is_warning) { classNames.push('is-warning'); }
    return classNames;
  },

  url() {
    const attrs = this.attrs;
    const data = attrs.data;

    const badgeId = data.badge_id;
    if (badgeId) {
      let badgeSlug = data.badge_slug;

      if (!badgeSlug) {
        const badgeName = data.badge_name;
        badgeSlug = badgeName.replace(/[^A-Za-z0-9_]+/g, '-').toLowerCase();
      }

      let username = data.username;
      username = username ? "?username=" + username.toLowerCase() : "";
      return Discourse.getURL('/badges/' + badgeId + '/' + badgeSlug + username);
    }

    const topicId = attrs.topic_id;
    if (topicId) {
      return postUrl(attrs.slug, topicId, attrs.post_number);
    }

    if (attrs.notification_type === INVITED_TYPE) {
      return Discourse.getURL('/users/' + data.display_username);
    }

    if (data.group_id) {
      return Discourse.getURL('/users/' + data.username + '/messages/group/' + data.group_name);
    }
  },

  description() {
    const data = this.attrs.data;
    const badgeName = data.badge_name;
    if (badgeName) { return escapeExpression(badgeName); }

    const title = data.topic_title;
    return Ember.isEmpty(title) ? "" : escapeExpression(title);
  },

  text(notificationType, notName) {
    const { attrs } = this;
    const data = attrs.data;
    const scope = (notName === 'custom') ? data.message : `notifications.${notName}`;

    if (notificationType === GROUP_SUMMARY_TYPE) {
      const count = data.inbox_count;
      const group_name = data.group_name;
      return I18n.t(scope, { count, group_name });
    }

    const username = data.display_username;
    const description = this.description();
    if (notificationType === LIKED_TYPE && data.count > 1) {
      const count = data.count - 2;
      const username2 = data.username2;
      if (count===0) {
        return I18n.t('notifications.liked_2', {description, username, username2});
      } else {
        return I18n.t('notifications.liked_many', {description, username, username2, count});
      }
    }

    return I18n.t(scope, {description, username});
  },

  html(attrs) {
    const notificationType = attrs.notification_type;
    const lookup = this.site.get('notificationLookup');
    const notName = lookup[notificationType];

    const contents = new RawHtml({ html: `<div>${emojiUnescape(this.text(notificationType, notName))}</div>` });
    const href = this.url();
    const alt = I18n.t(`notifications.alt.${notName}`);
    return href ? h('a', { attributes: { href, alt, 'data-auto-route': true } }, contents) : contents;
  },

  click(e) {
    this.attrs.set('read', true);
    const id = this.attrs.id;
    setTransientHeader("Discourse-Clear-Notifications", id);
    if (document && document.cookie) {
      document.cookie = `cn=${id}; expires=Fri, 31 Dec 9999 23:59:59 GMT`;
    }
    if (wantsNewWindow(e)) { return; }
    e.preventDefault();

    this.sendWidgetEvent('linkClicked');
    DiscourseURL.routeTo(this.url());
  }
});
