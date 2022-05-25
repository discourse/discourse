import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import Component from "@ember/component";
import I18n from "I18n";
import { alias } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import { iconHTML } from "discourse-common/lib/icon-library";
import { htmlSafe } from "@ember/template";

const TITLES = {
  [PRIVATE_MESSAGE]: "topic.private_message",
  [CREATE_TOPIC]: "topic.create_long",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft",
};

export default Component.extend({
  classNames: ["composer-action-title"],
  options: alias("model.replyOptions"),
  action: alias("model.action"),

  // Note we update when some other attributes like tag/category change to allow
  // text customizations to use those.
  @discourseComputed("options", "action", "model.tags", "model.category")
  actionTitle(opts, action) {
    let result = this.model.customizationFor("actionTitle");
    if (result) {
      return result;
    }

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

    return htmlSafe(editTitle);
  },

  _formatReplyToTopic(link) {
    return htmlSafe(
      `<a class="topic-link" href="${link.href}" data-topic-id="${this.get(
        "model.topic.id"
      )}">${link.anchor}</a>`
    );
  },

  _formatReplyToUserPost(avatar, link) {
    const htmlLink = `<a class="user-link" href="${link.href}">${link.anchor}</a>`;
    return htmlSafe(`${avatar}${htmlLink}`);
  },
});
