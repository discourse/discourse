import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import DiscourseURL, { userPath } from "discourse/lib/url";
import { empty, or } from "@ember/object/computed";
import { setting } from "discourse/lib/computed";
import I18n from "I18n";
import User from "discourse/models/user";
import { isEmpty } from "@ember/utils";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { inject as service } from "@ember/service";
import { action } from "@ember/object";

export default class UsernamePreference extends Component {
  @service siteSettings;
  @service dialog;

  @tracked editing = false;
  @tracked newUsername = this.args.user.username;
  @tracked errorMessage = null;
  @tracked saving = false;
  @tracked taken = false;

  @setting("max_username_length") maxLength;
  @setting("min_username_length") minLength;
  @empty("newUsername") newUsernameEmpty;

  @or("saving", "newUsernameEmpty", "taken", "unchanged", "errorMessage")
  saveDisabled;

  get unchanged() {
    return this.newUsername === this.args.user.username;
  }

  get saveButtonText() {
    return this.saving ? I18n.t("saving") : I18n.t("user.change");
  }

  @action
  toggleEditing() {
    this.editing = !this.editing;

    this.newUsername = this.args.user.username;
    this.errorMessage = null;
    this.saving = false;
    this.taken = false;
  }

  @action
  async onInput(event) {
    this.newUsername = event.target.value;
    this.taken = false;
    this.errorMessage = null;

    if (isEmpty(this.newUsername)) {
      return;
    }

    if (this.newUsername === this.args.user.username) {
      return;
    }

    if (this.newUsername.length < this.minLength) {
      this.errorMessage = I18n.t("user.name.too_short");
      return;
    }

    const result = await User.checkUsername(
      this.newUsername,
      undefined,
      this.args.user.id
    );

    if (result.errors) {
      this.errorMessage = result.errors.join(" ");
    } else if (result.available === false) {
      this.taken = true;
    }
  }

  @action
  changeUsername() {
    return this.dialog.yesNoConfirm({
      title: I18n.t("user.change_username.confirm"),
      didConfirm: async () => {
        this.saving = true;

        try {
          await this.args.user.changeUsername(this.newUsername);
          DiscourseURL.redirectTo(
            userPath(this.newUsername.toLowerCase() + "/preferences")
          );
        } catch (e) {
          popupAjaxError(e);
        } finally {
          this.saving = false;
        }
      },
    });
  }
}
