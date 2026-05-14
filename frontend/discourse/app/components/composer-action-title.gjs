/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed, set } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import ComposerActions from "discourse/components/composer-actions";
import escape from "discourse/lib/escape";
import { iconHTML } from "discourse/lib/icon-library";
import {
  ADD_TRANSLATION,
  CREATE_SHARED_DRAFT,
  EDIT,
  EDIT_SHARED_DRAFT,
  REPLY,
} from "discourse/models/composer";
import { i18n } from "discourse-i18n";

const TITLES = {
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft",
  [ADD_TRANSLATION]: "composer.translations.title",
};

@tagName("")
export default class ComposerActionTitle extends Component {
  // Note we update when some other attributes like tag/category change to allow
  // text customizations to use those.

  @service composer;

  @computed("model.replyOptions")
  get options() {
    return this.model?.replyOptions;
  }

  set options(value) {
    set(this, "model.replyOptions", value);
  }

  @computed("model.action")
  get action() {
    return this.model?.action;
  }

  set action(value) {
    set(this, "model.action", value);
  }

  @computed("action", "model.post.can_edit", "model.topic")
  get canEditReplyTo() {
    return (
      this.action === EDIT &&
      !!this.model?.post?.can_edit &&
      !!this.model?.topic
    );
  }

  @action
  openChangeReplyToModal() {
    this.composer.openChangeReplyToModal();
  }

  @computed("options", "action", "model.tags", "model.category")
  get actionTitle() {
    const result = this.model.customizationFor("actionTitle");
    if (result) {
      return result;
    }

    if (TITLES[this.action]) {
      return i18n(TITLES[this.action]);
    }

    if (this.action === REPLY) {
      if (this.options.userAvatar && this.options.userLink) {
        return this._formatReplyToUserPost(
          this.options.userAvatar,
          this.options.userLink
        );
      } else if (this.options.topicLink) {
        return this._formatReplyToTopic(this.options.topicLink);
      }
    }

    if (this.action === EDIT) {
      if (
        this.options.userAvatar &&
        this.options.userLink &&
        this.options.postLink
      ) {
        return this._formatEditUserPost(
          this.options.userAvatar,
          this.options.userLink,
          this.options.postLink
        );
      }
    }
  }

  @computed("options.originalUser")
  get replyTargetSegment() {
    const originalUser = this.options?.originalUser;
    if (!originalUser) {
      return null;
    }
    return trustHTML(
      `${iconHTML("share", { class: "reply-to-glyph" })}
       ${originalUser.avatar}
       <span class="original-username">${escape(originalUser.username)}</span>`
    );
  }

  _formatEditUserPost(userAvatar, userLink, postLink) {
    return trustHTML(`
      <a class="post-link" href="${postLink.href}">${postLink.anchor}</a>
      ${userAvatar}
      <span class="username">${escape(userLink.anchor)}</span>
    `);
  }

  _formatReplyToTopic(link) {
    return trustHTML(
      `<a class="topic-link" href="${link.href}" data-topic-id="${this.get(
        "model.topic.id"
      )}">${link.anchor}</a>`
    );
  }

  _formatReplyToUserPost(avatar, link) {
    const htmlLink = `<a class="user-link" href="${link.href}">${escape(
      link.anchor
    )}</a>`;
    return trustHTML(`${avatar}${htmlLink}`);
  }

  <template>
    <div class="composer-action-title" ...attributes>

      <ComposerActions
        @composerModel={{this.model}}
        @replyOptions={{this.model.replyOptions}}
        @action={{this.model.action}}
        @tabindex={{this.tabindex}}
        @topic={{this.model.topic}}
        @post={{this.model.post}}
        @options={{hash mobilePlacementStrategy="fixed"}}
      />

    </div>
  </template>
}
