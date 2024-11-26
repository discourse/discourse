import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import {
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import escape from "discourse-common/lib/escape";
import { iconHTML } from "discourse-common/lib/icon-library";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

const TITLES = {
  [PRIVATE_MESSAGE]: "topic.private_message",
  [CREATE_TOPIC]: "topic.create_long",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft",
};

@classNames("composer-action-title")
export default class ComposerActionTitle extends Component {
  @alias("model.replyOptions") options;
  @alias("model.action") action;

  // Note we update when some other attributes like tag/category change to allow
  // text customizations to use those.
  @discourseComputed("options", "action", "model.tags", "model.category")
  actionTitle(opts, action) {
    const result = this.model.customizationFor("actionTitle");
    if (result) {
      return result;
    }

    if (TITLES[action]) {
      return i18n(TITLES[action]);
    }

    if (action === REPLY) {
      if (opts.userAvatar && opts.userLink) {
        return this._formatReplyToUserPost(opts.userAvatar, opts.userLink);
      } else if (opts.topicLink) {
        return this._formatReplyToTopic(opts.topicLink);
      }
    }

    if (action === EDIT) {
      if (opts.userAvatar && opts.userLink && opts.postLink) {
        return this._formatEditUserPost(
          opts.userAvatar,
          opts.userLink,
          opts.postLink,
          opts.originalUser
        );
      }
    }
  }

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
  }

  _formatReplyToTopic(link) {
    return htmlSafe(
      `<a class="topic-link" href="${link.href}" data-topic-id="${this.get(
        "model.topic.id"
      )}">${link.anchor}</a>`
    );
  }

  _formatReplyToUserPost(avatar, link) {
    const htmlLink = `<a class="user-link" href="${link.href}">${escape(
      link.anchor
    )}</a>`;
    return htmlSafe(`${avatar}${htmlLink}`);
  }
}
