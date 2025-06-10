import Component, { Input, Textarea } from "@ember/component";
import { fn } from "@ember/helper";
import { on } from "@ember/modifier";
import { and, equal } from "@ember/object/computed";
import { htmlSafe } from "@ember/template";
import { tagName } from "@ember-decorators/component";
import concatClass from "discourse/helpers/concat-class";
import discourseComputed from "discourse/lib/decorators";
import { applyValueTransformer } from "discourse/lib/transformer";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import { i18n } from "discourse-i18n";

@tagName("")
export default class FlagActionType extends Component {
  @and("flag.require_message", "selected") showMessageInput;
  @and("flag.isIllegal", "selected") showConfirmation;
  @equal("flag.name_key", "notify_user") isNotifyUser;

  get flagDescription() {
    return applyValueTransformer("flag-description", this.description, {
      nameKey: this.flag.name_key,
    });
  }

  @discourseComputed("flag.name_key")
  wrapperClassNames(nameKey) {
    return `flag-action-type ${nameKey}`;
  }

  @discourseComputed("flag.name_key")
  customPlaceholder(nameKey) {
    return applyValueTransformer(
      "flag-custom-placeholder",
      i18n("flagging.custom_placeholder_" + nameKey, {
        defaultValue: i18n("flagging.custom_placeholder_notify_moderators"),
      }),
      { nameKey }
    );
  }

  @discourseComputed("flag.name", "flag.name_key", "username")
  formattedName(name, nameKey, username) {
    if (["notify_user", "notify_moderators"].includes(nameKey)) {
      return name.replace(/{{username}}|%{username}/, username);
    } else {
      return applyValueTransformer(
        "flag-formatted-name",
        i18n("flagging.formatted_name." + nameKey, {
          defaultValue: name,
        }),
        { nameKey }
      );
    }
  }

  @discourseComputed("flag", "selectedFlag")
  selected(flag, selectedFlag) {
    return flag === selectedFlag;
  }

  @discourseComputed("flag.description", "flag.short_description")
  description(long_description, short_description) {
    return this.site.mobileView ? short_description : long_description;
  }

  @discourseComputed("message.length")
  customMessageLengthClasses(messageLength) {
    return messageLength < this.siteSettings.min_personal_message_post_length
      ? "too-short"
      : "ok";
  }

  @discourseComputed("message.length")
  customMessageLength(messageLength) {
    const len = messageLength || 0;
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

  <template>
    <div class={{this.wrapperClassNames}}>
      {{#if this.isNotifyUser}}
        <h3>{{this.formattedName}}</h3>
        <div class="controls">
          <label class="radio checkbox-label">
            <input
              id="radio_{{this.flag.name_key}}"
              {{on "click" (fn this.changePostActionType this.flag)}}
              type="radio"
              name="post_action_type_index"
            />

            <div class="flag-action-type-details">
              <span class="description">{{htmlSafe this.flagDescription}}</span>
              {{#if this.showMessageInput}}
                <Textarea
                  name="message"
                  class="flag-message"
                  placeholder={{this.customPlaceholder}}
                  aria-label={{i18n "flagging.notify_user_textarea_label"}}
                  @value={{this.message}}
                />
                <div
                  class={{concatClass
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
        {{#if this.staffFlagsAvailable}}
          <hr />
          <h3>{{i18n "flagging.notify_staff"}}</h3>
        {{/if}}
      {{else}}
        <div class="controls {{this.flag.name_key}}">
          <label class="radio checkbox-label">
            <input
              id="radio_{{this.flag.name_key}}"
              {{on "click" (fn this.changePostActionType this.flag)}}
              checked={{this.selected}}
              type="radio"
              name="post_action_type_index"
            />
            <div class="flag-action-type-details">
              <strong class="flag-name">{{this.formattedName}}</strong>
              <div class="description">{{htmlSafe this.flagDescription}}</div>
              {{#if this.showMessageInput}}
                <Textarea
                  name="message"
                  class="flag-message"
                  placeholder={{this.customPlaceholder}}
                  aria-label={{i18n
                    "flagging.notify_moderators_textarea_label"
                  }}
                  @value={{this.message}}
                />
                <div
                  class={{concatClass
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
              <Input
                name="confirmation"
                @type="checkbox"
                @checked={{this.isConfirmed}}
              />
              <span>{{i18n "flagging.confirmation_illegal"}}</span>
            </label>
          {{/if}}
        </div>
      {{/if}}
    </div>
  </template>
}
