import Component from "@glimmer/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { trustHTML } from "@ember/template";
import withEventValue from "discourse/helpers/with-event-value";
import { applyValueTransformer } from "discourse/lib/transformer";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import dConcatClass from "discourse/ui-kit/helpers/d-concat-class";
import { i18n } from "discourse-i18n";

export default class FlagActionType extends Component {
  @service site;
  @service siteSettings;

  get showMessageInput() {
    return this.args.flag?.require_message && this.selected;
  }

  get showConfirmation() {
    return this.args.flag?.isIllegal && this.selected;
  }

  get isNotifyUser() {
    return this.args.flag?.name_key === "notify_user";
  }

  get flagDescription() {
    return applyValueTransformer("flag-description", this.description, {
      nameKey: this.args.flag.name_key,
    });
  }

  get wrapperClassNames() {
    return `flag-action-type ${this.args.flag?.name_key}`;
  }

  get customPlaceholder() {
    return applyValueTransformer(
      "flag-custom-placeholder",
      i18n("flagging.custom_placeholder_" + this.args.flag?.name_key, {
        defaultValue: i18n("flagging.custom_placeholder_notify_moderators"),
      }),
      { nameKey: this.args.flag?.name_key }
    );
  }

  get formattedName() {
    const flag = this.args.flag;
    if (["notify_user", "notify_moderators"].includes(flag?.name_key)) {
      return flag?.name?.replace(
        /{{username}}|%{username}/,
        this.args.username
      );
    } else {
      return applyValueTransformer(
        "flag-formatted-name",
        i18n("flagging.formatted_name." + flag?.name_key, {
          defaultValue: flag?.name,
        }),
        { nameKey: flag?.name_key }
      );
    }
  }

  get selected() {
    return this.args.flag === this.args.selectedFlag;
  }

  get description() {
    return this.site.mobileView
      ? this.args.flag?.short_description
      : this.args.flag?.description;
  }

  get customMessageLengthClasses() {
    return this.args.message?.length <
      this.siteSettings.min_personal_message_post_length
      ? "too-short"
      : "ok";
  }

  get customMessageLength() {
    const len = this.args.message?.length || 0;
    const minLen = this.siteSettings.min_personal_message_post_length;
    if (len === 0) {
      return i18n("flagging.custom_message.at_least", { count: minLen });
    } else if (len < minLen) {
      return i18n("flagging.custom_message.more", { count: minLen - len });
    } else {
      return i18n("flagging.custom_message.left", {
        count: MAX_MESSAGE_LENGTH - len,
      });
    }
  }

  @action
  changeConfirmed(event) {
    this.args.onChangeConfirmed(event.target.checked);
  }

  <template>
    <div class={{this.wrapperClassNames}}>
      {{#if this.isNotifyUser}}
        <h3>{{this.formattedName}}</h3>
        <div class="controls">
          <label class="radio checkbox-label">
            <input
              checked={{this.selected}}
              id="radio_{{@flag.name_key}}"
              name="post_action_type_index"
              type="radio"
              {{on "click" (fn @changePostActionType @flag)}}
            />

            <div class="flag-action-type-details">
              <span class="description">{{trustHTML
                  this.flagDescription
                }}</span>
              {{#if this.showMessageInput}}
                {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                <textarea
                  aria-label={{i18n "flagging.notify_user_textarea_label"}}
                  class="flag-message"
                  name="message"
                  placeholder={{this.customPlaceholder}}
                  value={{@message}}
                  {{on "input" (withEventValue @onChangeMessage)}}
                />
                <div
                  class={{dConcatClass
                    "custom-message-length"
                    this.customMessageLengthClasses
                  }}
                >
                  {{this.customMessageLength}}
                </div>
              {{/if}}
            </div>
          </label>
        </div>
        {{#if @staffFlagsAvailable}}
          <hr />
          <h3>{{i18n "flagging.notify_staff"}}</h3>
        {{/if}}
      {{else}}
        <div class="controls {{@flag.name_key}}">
          <label class="radio checkbox-label">
            <input
              checked={{this.selected}}
              id="radio_{{@flag.name_key}}"
              name="post_action_type_index"
              type="radio"
              {{on "click" (fn @changePostActionType @flag)}}
            />
            <div class="flag-action-type-details">
              <strong class="flag-name">{{this.formattedName}}</strong>
              <div class="description">{{trustHTML this.flagDescription}}</div>
              {{#if this.showMessageInput}}
                {{! eslint-disable-next-line ember/template-no-nested-interactive }}
                <textarea
                  aria-label={{i18n
                    "flagging.notify_moderators_textarea_label"
                  }}
                  class="flag-message"
                  name="message"
                  placeholder={{this.customPlaceholder}}
                  value={{@message}}
                  {{on "input" (withEventValue @onChangeMessage)}}
                />
                <div
                  class={{dConcatClass
                    "custom-message-length"
                    this.customMessageLengthClasses
                  }}
                >
                  {{this.customMessageLength}}
                </div>
              {{/if}}
            </div>
          </label>
          {{#if this.showConfirmation}}
            <label class="checkbox-label flag-confirmation">
              <input
                checked={{@isConfirmed}}
                name="confirmation"
                type="checkbox"
                {{on "change" this.changeConfirmed}}
              />
              <span>{{i18n "flagging.confirmation_illegal"}}</span>
            </label>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
