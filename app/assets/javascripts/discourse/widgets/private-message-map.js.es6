import { iconNode } from 'discourse/helpers/fa-icon';
import { createWidget } from 'discourse/widgets/widget';
import { h } from 'virtual-dom';
import { avatarFor } from 'discourse/widgets/post';

createWidget('pm-map-user-group', {
  tagName: 'div.user.group',

  html(attrs) {
    const link = h('a', { attributes: { href: Discourse.getURL(`/groups/${attrs.name}`) } }, attrs.name);
    return [iconNode('users'), ' ', link];
  }
});

createWidget('pm-remove-link', {
  tagName: 'a.remove-invited',

  html() {
    return iconNode('times');
  },

  click() {
    bootbox.confirm(I18n.t("private_message_info.remove_allowed_user", {name: this.attrs.username}), (confirmed) => {
      if (confirmed) { this.sendWidgetAction('removeAllowedUser', this.attrs); }
    });
  }
});

createWidget('pm-map-user', {
  tagName: 'div.user',

  html(attrs) {
    const user = attrs.user;
    const avatar = avatarFor('small', { template: user.avatar_template, username: user.username });
    const link = h('a', { attributes: { href: user.get('path') } }, [ avatar, ' ', user.username ]);

    const result = [link];
    if (attrs.canRemoveAllowedUsers) {
      result.push(' ');
      result.push(this.attach('pm-remove-link', user));
    }

    return result;
  }
});

export default createWidget('private-message-map', {
  tagName: 'section.information.private-message-map',

  html(attrs) {
    const participants = [];

    if (attrs.allowedGroups.length) {
      participants.push(attrs.allowedGroups.map(ag => this.attach('pm-map-user-group', ag)));
    }

    if (attrs.allowedUsers.length) {
      participants.push(attrs.allowedUsers.map(ag => {
        return this.attach('pm-map-user', { user: ag, canRemoveAllowedUsers: attrs.canRemoveAllowedUsers });
      }));
    }

    const result = [ h('h3', [iconNode('envelope'), ' ', I18n.t('private_message_info.title')]),
                     h('div.participants.clearfix', participants) ];

    if (attrs.canInvite) {
      result.push(h('div.controls', this.attach('button', {
        action: 'showInvite',
        label: 'private_message_info.invite',
        className: 'btn'
      })));
    }

    return result;
  }
});
