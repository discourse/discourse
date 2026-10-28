import Component from "@glimmer/component";
import { action, get } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import ComposerActions from "discourse/components/composer-actions";
import escape from "discourse/lib/escape";
import { iconHTML } from "discourse/lib/icon-library";
import { EDIT } from "discourse/models/composer";
import DButton from "discourse/ui-kit/d-button";

export default class ComposerActionTitle extends Component {
  @service composer;

  get options() {
    return this.args.model?.replyOptions;
  }

  get canEditReplyTo() {
    const model = this.args.model;
    if (!model) {
      return false;
    }

    return (
      get(model, "action") === EDIT && !!model.post?.can_edit && !!model.topic
    );
  }

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
          @action={{@model.action}}
          @composerModel={{@model}}
          @post={{@model.post}}
          @replyOptions={{@model.replyOptions}}
          @topic={{@model.topic}}
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
