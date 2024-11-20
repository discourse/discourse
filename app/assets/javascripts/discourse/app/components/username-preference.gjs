import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { on } from "@ember/modifier";
import { action } from "@ember/object";
import { empty, or } from "@ember/object/computed";
import { service } from "@ember/service";
import { htmlSafe } from "@ember/template";
import { isEmpty } from "@ember/utils";
import DButton from "discourse/components/d-button";
import DModalCancel from "discourse/components/d-modal-cancel";
import { popupAjaxError } from "discourse/lib/ajax-error";
import { setting } from "discourse/lib/computed";
import DiscourseURL, { userPath } from "discourse/lib/url";
import User from "discourse/models/user";
import { i18n } from "discourse-i18n";

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
    return this.saving ? i18n("saving") : i18n("user.change");
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
      this.errorMessage = i18n("user.name.too_short");
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
      title: i18n("user.change_username.confirm"),
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

  <template>
    {{#if this.editing}}
      <form class="form-horizontal">
        <div class="control-group">
          <Input
            {{on "input" this.onInput}}
            @value={{this.newUsername}}
            maxlength={{this.maxLength}}
            class="input-xxlarge username-preference__input"
          />

          <div class="instructions">
            <p>
              {{#if this.taken}}
                {{i18n "user.change_username.taken"}}
              {{/if}}
              <span>{{this.errorMessage}}</span>
            </p>
          </div>
        </div>

        <div class="control-group">
          <DButton
            @action={{this.changeUsername}}
            @disabled={{this.saveDisabled}}
            @translatedLabel={{this.saveButtonText}}
            type="submit"
            class="btn-primary username-preference__submit"
          />

          <DModalCancel @close={{this.toggleEditing}} />

          {{#if this.saved}}{{i18n "saved"}}{{/if}}
        </div>
      </form>
    {{else}}
      <div class="controls">
        <span
          class="static username-preference__current-username"
        >{{@user.username}}</span>

        {{#if @user.can_edit_username}}
          <DButton
            @action={{this.toggleEditing}}
            @icon="pencil"
            @title="user.username.edit"
            class="btn-small username-preference__edit-username"
          />
        {{/if}}
      </div>

      {{#if this.siteSettings.enable_mentions}}
        <div class="instructions">
          {{htmlSafe
            (i18n "user.username.short_instructions" username=@user.username)
          }}
        </div>
      {{/if}}
    {{/if}}
  </template>
}
