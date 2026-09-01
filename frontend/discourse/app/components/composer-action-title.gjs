/* eslint-disable ember/no-classic-components */
import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import ComposerActions from "discourse/components/composer-actions";
import escape from "discourse/lib/escape";
import { iconHTML } from "discourse/lib/icon-library";
import { EDIT } from "discourse/models/composer";
import DButton from "discourse/ui-kit/d-button";

@tagName("")
export default class ComposerActionTitle extends Component {
  @service composer;

  @computed("model.replyOptions")
  get options() {
    return this.model?.replyOptions;
  }

  @computed("model.action", "model.post.can_edit", "model.topic")
  get canEditReplyTo() {
    return (
      this.model?.action === EDIT &&
      !!this.model?.post?.can_edit &&
      !!this.model?.topic
    );
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

  @action
  openChangeReplyToModal() {
    this.composer.openChangeReplyToModal();
  }

  <template>
    <div class="composer-action-title" ...attributes>
      <span aria-level="1" class="action-title" role="heading">
        <ComposerActions
          @action={{this.model.action}}
          @composerModel={{this.model}}
          @post={{this.model.post}}
          @replyOptions={{this.model.replyOptions}}
          @topic={{this.model.topic}}
        />

        {{#if this.replyTargetSegment}}
          {{#if this.canEditReplyTo}}
            <DButton
              class="composer-edit-reply-to btn-default"
              @action={{this.openChangeReplyToModal}}
              @title="composer.change_reply_to.open"
              @translatedLabel={{this.replyTargetSegment}}
            />
          {{else}}
            {{this.replyTargetSegment}}
          {{/if}}
        {{/if}}
      </span>
    </div>
  </template>
}
