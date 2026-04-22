/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { hash } from "@ember/helper";
import { action, computed, set } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import DButton from "discourse/components/d-button";
import ChangeReplyTo from "discourse/components/modal/change-reply-to";
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
import ComposerActions from "discourse/select-kit/components/composer-actions";
import { i18n } from "discourse-i18n";

const TITLES = {
  [PRIVATE_MESSAGE]: "topic.private_message",
  [CREATE_TOPIC]: "topic.create_long",
  [CREATE_SHARED_DRAFT]: "composer.create_shared_draft",
  [EDIT_SHARED_DRAFT]: "composer.edit_shared_draft",
  [ADD_TRANSLATION]: "composer.translations.title",
};

@tagName("")
export default class ComposerActionTitle extends Component {
  // Note we update when some other attributes like tag/category change to allow
  // text customizations to use those.

  @service modal;

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
  removeReplyTo() {
    this.model?.setReplyTo(null, null);
  }

  @action
  openChangeReplyToModal() {
    const model = this.model;
    this.modal.show(ChangeReplyTo, {
      model: {
        topic: model.topic,
        editingPostNumber: model.post?.post_number,
        currentPostNumber: model.reply_to_post_number,
        onSelect: (post) => {
          model.setReplyTo(post.post_number, {
            id: post.user_id,
            username: post.username,
            name: post.name,
            avatar_template: post.avatar_template,
          });
        },
      },
    });
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
          this.options.postLink,
          this.options.originalUser
        );
      }
    }
  }

  _formatEditUserPost(userAvatar, userLink, postLink, originalUser) {
    let editTitle = `
      <a class="post-link" href="${postLink.href}">${postLink.anchor}</a>
      ${userAvatar}
      <span class="username">${escape(userLink.anchor)}</span>
    `;

    if (originalUser) {
      editTitle += `
        ${iconHTML("share", { class: "reply-to-glyph" })}
        ${originalUser.avatar}
        <span class="original-username">${escape(originalUser.username)}</span>
      `;
    }

    return trustHTML(editTitle);
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
        @canWhisper={{this.canWhisper}}
        @canUnlistTopic={{this.canUnlistTopic}}
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

      {{#if this.canEditReplyTo}}
        <span class="composer-edit-reply-to">
          <DButton
            @icon="pencil"
            @action={{this.openChangeReplyToModal}}
            @title="composer.change_reply_to.open"
            class="btn-flat composer-edit-reply-to__change"
          />
          {{#if this.model.reply_to_post_number}}
            <DButton
              @icon="xmark"
              @action={{this.removeReplyTo}}
              @title="composer.change_reply_to.remove"
              class="btn-flat composer-edit-reply-to__remove"
            />
          {{/if}}
        </span>
      {{/if}}
    </div>
  </template>
}
