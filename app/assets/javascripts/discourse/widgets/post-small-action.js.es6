import { createWidget } from 'discourse/widgets/widget';
import RawHtml from 'discourse/widgets/raw-html';
import { iconNode } from 'discourse/helpers/fa-icon';
import { h } from 'virtual-dom';
import { actionDescriptionHtml } from 'discourse/components/small-action';
import { avatarFor } from 'discourse/widgets/post';

const icons = {
  'closed.enabled': 'lock',
  'closed.disabled': 'unlock-alt',
  'autoclosed.enabled': 'lock',
  'autoclosed.disabled': 'unlock-alt',
  'archived.enabled': 'folder',
  'archived.disabled': 'folder-open',
  'pinned.enabled': 'thumb-tack',
  'pinned.disabled': 'thumb-tack unpinned',
  'pinned_globally.enabled': 'thumb-tack',
  'pinned_globally.disabled': 'thumb-tack unpinned',
  'visible.enabled': 'eye',
  'visible.disabled': 'eye-slash',
  'split_topic': 'sign-out',
  'invited_user': 'plus-circle',
  'removed_user': 'minus-circle',
  'public_topic': 'comment',
  'private_topic': 'envelope'
};

export default createWidget('post-small-action', {
  buildKey: attrs => `post-small-act-${attrs.id}`,
  tagName: 'div.small-action.onscreen-post.clearfix',

  buildId(attrs) {
    return `post_${attrs.post_number}`;
  },

  buildClasses(attrs) {
    if (attrs.deleted) { return 'deleted'; }
  },

  html(attrs) {
    const contents = [];

    if (attrs.canDelete) {
      contents.push(this.attach('button', {
        icon: 'times',
        action: 'deletePost',
        title: 'post.controls.delete'
      }));
    }

    if (attrs.canEdit) {
      contents.push(this.attach('button', {
        icon: 'pencil',
        action: 'editPost',
        title: 'post.controls.edit'
      }));
    }

    contents.push(avatarFor.call(this, 'small', {
      template: attrs.avatar_template,
      username: attrs.avatar,
      url: attrs.usernameUrl
    }));

    const description = actionDescriptionHtml(attrs.actionCode, attrs.created_at, attrs.actionCodeWho);
    contents.push(new RawHtml({ html: `<p>${description}</p>` }));

    if (attrs.cooked) {
      contents.push(new RawHtml({ html: `<div class='custom-message'>${attrs.cooked}</div>` }));
    }

    return [
      h('div.topic-avatar', iconNode(icons[attrs.actionCode] || 'exclamation')),
      h('div.small-action-desc', contents)
    ];
  }
});
