import { default as computed } from 'ember-addons/ember-computed-decorators';
import { PRIVATE_MESSAGE, CREATE_TOPIC, REPLY, EDIT } from "discourse/models/composer";
import { iconHTML } from 'discourse-common/lib/icon-library';

export default Ember.Component.extend({
  classNames: ["composer-action-title"],
  options: Ember.computed.alias("model.replyOptions"),
  action: Ember.computed.alias("model.action"),
  isEditing: Ember.computed.equal("action", EDIT),

  @computed("options", "action")
  actionTitle(opts, action) {
    switch (action) {
      case PRIVATE_MESSAGE:
        return I18n.t("topic.private_message");
      case CREATE_TOPIC:
        return I18n.t("topic.create_long");
      case REPLY:
        if (opts.userAvatar && opts.userLink) {
          return this._formatReplyToUserPost(opts.userAvatar, opts.userLink);
        } else if (opts.topicLink) {
          return this._formatReplyToTopic(opts.topicLink);
        }
      case EDIT:
        if (opts.userAvatar && opts.userLink && opts.postLink) {
          return this._formatEditUserPost(
            opts.userAvatar,
            opts.userLink,
            opts.postLink,
            opts.originalUser
          );
        }
    };
  },

  _formatEditUserPost(userAvatar, userLink, postLink, originalUser) {
    let editTitle = `
      <a class="post-link" href="${postLink.href}">${postLink.anchor}</a>
      ${userAvatar}
      <span class="username">${userLink.anchor}</span>
    `;

    if (originalUser) {
      editTitle += `
        ${iconHTML("mail-forward", { class: "reply-to-glyph" })}
        ${originalUser.avatar}
        <span class="original-username">${originalUser.username}</span>
      `;
    }

    return editTitle.htmlSafe();
  },

  _formatReplyToTopic(link) {
    return `<a class="topic-link" href="${link.href}">${link.anchor}</a>`.htmlSafe();
  },

  _formatReplyToUserPost(avatar, link) {
    const htmlLink = `<a class="user-link" href="${link.href}">${link.anchor}</a>`;
    return `${avatar}${htmlLink}`.htmlSafe();
  },

});
