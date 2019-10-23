import Component from "@ember/component";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import computed from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["flag-action-type"],

  @computed("flag.name_key")
  customPlaceholder(nameKey) {
    return I18n.t("flagging.custom_placeholder_" + nameKey);
  },

  @computed("flag.name", "flag.name_key", "flag.is_custom_flag", "username")
  formattedName(name, nameKey, isCustomFlag, username) {
    if (isCustomFlag) {
      return name.replace("{{username}}", username);
    } else {
      return I18n.t("flagging.formatted_name." + nameKey);
    }
  },

  @computed("flag", "selectedFlag")
  selected(flag, selectedFlag) {
    return flag === selectedFlag;
  },

  showMessageInput: Ember.computed.and("flag.is_custom_flag", "selected"),
  showDescription: Ember.computed.not("showMessageInput"),
  isNotifyUser: Ember.computed.equal("flag.name_key", "notify_user"),

  @computed("flag.description", "flag.short_description")
  description(long_description, short_description) {
    return this.site.mobileView ? short_description : long_description;
  },

  @computed("message.length")
  customMessageLengthClasses(messageLength) {
    return messageLength <
      Discourse.SiteSettings.min_personal_message_post_length
      ? "too-short"
      : "ok";
  },

  @computed("message.length")
  customMessageLength(messageLength) {
    const len = messageLength || 0;
    const minLen = Discourse.SiteSettings.min_personal_message_post_length;
    if (len === 0) {
      return I18n.t("flagging.custom_message.at_least", { count: minLen });
    } else if (len < minLen) {
      return I18n.t("flagging.custom_message.more", { count: minLen - len });
    } else {
      return I18n.t("flagging.custom_message.left", {
        count: MAX_MESSAGE_LENGTH - len
      });
    }
  },

  actions: {
    changePostActionType(at) {
      this.changePostActionType(at);
    }
  }
});
