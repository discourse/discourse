import Component from "@ember/component";
import { and, equal, not } from "@ember/object/computed";
import { tagName } from "@ember-decorators/component";
import { MAX_MESSAGE_LENGTH } from "discourse/models/post-action-type";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@tagName("")
export default class FlagActionType extends Component {
  @and("flag.require_message", "selected") showMessageInput;
  @and("flag.isIllegal", "selected") showConfirmation;
  @not("showMessageInput") showDescription;
  @equal("flag.name_key", "notify_user") isNotifyUser;

  @discourseComputed("flag.name_key")
  wrapperClassNames(nameKey) {
    return `flag-action-type ${nameKey}`;
  }

  @discourseComputed("flag.name_key")
  customPlaceholder(nameKey) {
    return i18n("flagging.custom_placeholder_" + nameKey, {
      defaultValue: i18n("flagging.custom_placeholder_notify_moderators"),
    });
  }

  @discourseComputed("flag.name", "flag.name_key", "username")
  formattedName(name, nameKey, username) {
    if (["notify_user", "notify_moderators"].includes(nameKey)) {
      return name.replace(/{{username}}|%{username}/, username);
    } else {
      return i18n("flagging.formatted_name." + nameKey, {
        defaultValue: name,
      });
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
}
