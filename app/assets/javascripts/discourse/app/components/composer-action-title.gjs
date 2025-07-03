import Component from "@ember/component";
import { hash } from "@ember/helper";
import { alias } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { classNames } from "@ember-decorators/component";
import PostLanguageSelector from "discourse/components/post-language-selector";
import discourseComputed from "discourse/lib/decorators";
import escape from "discourse/lib/escape";
import { iconHTML } from "discourse/lib/icon-library";
import {
  ADD_TRANSLATION,
  CREATE_SHARED_DRAFT,
  CREATE_TOPIC,
  EDIT,
  EDIT_SHARED_DRAFT,
  PRIVATE_MESSAGE,
  REPLY,
} from "discourse/models/composer";
import { i18n } from "discourse-i18n";
import ComposerActions from "select-kit/components/composer-actions";

const TITLES = {
  [PRIVATE_MESSAGE]: "topic.private_message",
  [CREATE_TOPIC]: "topic.create_long",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft",
  [ADD_TRANSLATION]: "composer.translations.title",
};

@classNames("composer-action-title")
export default class ComposerActionTitle extends Component {
  @service currentUser;
  @service siteSettings;

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

  get showPostLanguageSelector() {
    const allowedActions = [CREATE_TOPIC, EDIT, REPLY];
    if (
      this.currentUser &&
      this.siteSettings.content_localization_enabled &&
      this.currentUser.can_localize_content &&
      allowedActions.includes(this.model.action)
    ) {
      return true;
    }

    return false;
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

  <template>
    <ComposerActions
      @composerModel={{this.model}}
      @replyOptions={{this.model.replyOptions}}
      @canWhisper={{this.canWhisper}}
      @action={{this.model.action}}
      @tabindex={{this.tabindex}}
      @topic={{this.model.topic}}
      @post={{this.model.post}}
      @whisper={{this.model.whisper}}
      @noBump={{this.model.noBump}}
      @options={{hash mobilePlacementStrategy="fixed"}}
    />

    <span class="action-title" role="heading" aria-level="1">
      {{this.actionTitle}}
    </span>

    {{#if this.showPostLanguageSelector}}
      <PostLanguageSelector
        @composerModel={{this.model}}
        @selectedLanguage={{this.model.locale}}
      />
    {{/if}}
  </template>
}
