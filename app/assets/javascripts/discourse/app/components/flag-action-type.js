import Component from "@ember/component";
import { and, equal, not } from "@ember/object/computed";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import discourseComputed from "discourse-common/utils/decorators";
import I18n from "discourse-i18n";

export default Component.extend({
  tagName: "",

  @discourseComputed("flag.name_key")
  wrapperClassNames(nameKey) {
    return `flag-action-type ${nameKey}`;
  },

  @discourseComputed("flag.name_key")
  customPlaceholder(nameKey) {
    return I18n.t("flagging.custom_placeholder_" + nameKey, {
      defaultValue: I18n.t("flagging.custom_placeholder_notify_moderators"),
    });
  },

  @discourseComputed("flag.name", "flag.name_key", "username")
  formattedName(name, nameKey, username) {
    if (["notify_user", "notify_moderators"].includes(nameKey)) {
      return name.replace(/{{username}}|%{username}/, username);
    } else {
      return I18n.t("flagging.formatted_name." + nameKey, {
        defaultValue: name,
      });
    }
  },

  @discourseComputed("flag", "selectedFlag")
  selected(flag, selectedFlag) {
    return flag === selectedFlag;
  },

  showMessageInput: and("flag.is_custom_flag", "selected"),
  showConfirmation: and("flag.isIllegal", "selected"),
  showDescription: not("showMessageInput"),
  isNotifyUser: equal("flag.name_key", "notify_user"),

  @discourseComputed("flag.description", "flag.short_description")
  description(long_description, short_description) {
    return this.site.mobileView ? short_description : long_description;
  },

  @discourseComputed("message.length")
  customMessageLengthClasses(messageLength) {
    return messageLength < this.siteSettings.min_personal_message_post_length
      ? "too-short"
      : "ok";
  },

  @discourseComputed("message.length")
  customMessageLength(messageLength) {
    const len = messageLength || 0;
    const minLen = this.siteSettings.min_personal_message_post_length;
    if (len === 0) {
      return I18n.t("flagging.custom_message.at_least", { count: minLen });
    } else if (len < minLen) {
      return I18n.t("flagging.custom_message.more", { count: minLen - len });
    } else {
      return I18n.t("flagging.custom_message.left", {
        count: MAX_MESSAGE_LENGTH - len,
      });
    }
  },

  actions: {
    changePostActionType(at) {
      this.changePostActionType(at);
    },
  },
});
