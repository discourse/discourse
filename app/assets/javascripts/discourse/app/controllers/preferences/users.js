import Controller from "@ember/controller";
import { action, computed } from "@ember/object";
import { and } from "@ember/object/computed";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { uniqueItemsFromArray } from "discourse/lib/array-tools";
import discourseComputed from "discourse/lib/decorators";
import { makeArray } from "discourse/lib/helpers";
import { i18n } from "discourse-i18n";

export default class UsersController extends Controller {
  @and(
    "model.user_option.enable_allowed_pm_users",
    "model.user_option.allow_private_messages"
  )
  allowPmUsersEnabled;

  subpageTitle = i18n("user.preferences_nav.users");

  init() {
    super.init(...arguments);

    this.saveAttrNames = [
      "allow_private_messages",
      "muted_usernames",
      "allowed_pm_usernames",
      "enable_allowed_pm_users",
    ];
  }

  @computed("model.muted_usernames")
  get mutedUsernames() {
    let usernames = this.model.muted_usernames;

    if (typeof usernames === "string") {
      usernames = usernames.split(",").filter(Boolean);
    }

    return uniqueItemsFromArray(makeArray(usernames));
  }

  @computed("model.allowed_pm_usernames")
  get allowedPmUsernames() {
    let usernames = this.model.allowed_pm_usernames;

    if (typeof usernames === "string") {
      usernames = usernames.split(",").filter(Boolean);
    }

    return uniqueItemsFromArray(makeArray(usernames));
  }

  @action
  onChangeMutedUsernames(usernames) {
    this.model.set(
      "muted_usernames",
      uniqueItemsFromArray(usernames).join(",")
    );
  }

  @action
  onChangeAllowedPmUsernames(usernames) {
    this.model.set(
      "allowed_pm_usernames",
      uniqueItemsFromArray(usernames).join(",")
    );
  }

  @discourseComputed("model.user_option.allow_private_messages")
  disableAllowPmUsersSetting(allowPrivateMessages) {
    return !allowPrivateMessages;
  }

  @action
  save() {
    this.set("saved", false);

    return this.model
      .save(this.saveAttrNames)
      .then(() => this.set("saved", true))
      .catch(popupAjaxError);
  }
}
