import { alias, equal } from "@ember/object/computed";
import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";
import {
  PRIVATE_MESSAGE,
  CREATE_TOPIC,
  CREATE_SHARED_DRAFT,
  REPLY,
  EDIT,
  EDIT_SHARED_DRAFT
} from "discourse/models/composer";
import { iconHTML } from "discourse-common/lib/icon-library";

const TITLES = {
  [PRIVATE_MESSAGE]: "topic.private_message",
  [CREATE_TOPIC]: "topic.create_long",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft"
};

export default Component.extend({
  classNames: ["composer-action-title"],
  options: alias("model.replyOptions"),
  action: alias("model.action"),
  isEditing: equal("action", EDIT),

  @computed("options", "action")
  actionTitle(opts, action) {
    if (TITLES[action]) {
      return I18n.t(TITLES[action]);
    }

    switch (action) {
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
    }
  },

  _formatEditUserPost(userAvatar, userLink, postLink, originalUser) {
    let editTitle = `
      <a class="post-link" href="${postLink.href}">${postLink.anchor}</a>
      ${userAvatar}
      <span class="username">${userLink.anchor}</span>
    `;

    if (originalUser) {
      editTitle += `
        ${iconHTML("share", { class: "reply-to-glyph" })}
        ${originalUser.avatar}
        <span class="original-username">${originalUser.username}</span>
      `;
    }

    return editTitle.htmlSafe();
  },

  _formatReplyToTopic(link) {
    return `<a class="topic-link" href="${link.href}" data-topic-id="${this.get(
      "model.topic.id"
    )}">${link.anchor}</a>`.htmlSafe();
  },

  _formatReplyToUserPost(avatar, link) {
    const htmlLink = `<a class="user-link" href="${link.href}">${link.anchor}</a>`;
    return `${avatar}${htmlLink}`.htmlSafe();
  }
});
