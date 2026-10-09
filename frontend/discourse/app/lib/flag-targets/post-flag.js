import Flag from "discourse/lib/flag-targets/flag";
import { getAbsoluteURL } from "discourse/lib/get-url";
import { applyValueTransformer } from "discourse/lib/transformer";
import { i18n } from "discourse-i18n";

export default class PostFlag extends Flag {
  title() {
    return applyValueTransformer("post-flag-title", "flagging.title");
  }

  customSubmitLabel() {
    return "flagging.notify_action";
  }

  submitLabel() {
    return "flagging.action";
  }

  anonymousFlagDescription(post, email) {
    return i18n("anonymous_flagging.description", {
      email,
      topic_title: post.topic.title,
      url: getAbsoluteURL(post.url),
    });
  }

  flagCreatedEvent() {
    return "post:flag-created";
  }

  flagsAvailable(flagModal) {
    let flagsAvailable = flagModal.args.model.flagModel.flagsAvailable;

    flagsAvailable = flagsAvailable.filter((flag) => {
      return flag.applies_to.includes("Post");
    });

    // "message user" option should be at the top
    const notifyUserIndex = flagsAvailable.findIndex(
      (flag) => flag.name_key === "notify_user"
    );

    if (notifyUserIndex !== -1) {
      const notifyUser = flagsAvailable[notifyUserIndex];
      flagsAvailable.splice(notifyUserIndex, 1);
      flagsAvailable.splice(0, 0, notifyUser);
    }

    flagsAvailable = applyValueTransformer(
      "post-flag-available-flags",
      flagsAvailable
    );

    return flagsAvailable;
  }

  postActionFor(flagModal) {
    return flagModal.args.model.flagModel.actionByName?.[
      flagModal.selected.name_key
    ];
  }
}
