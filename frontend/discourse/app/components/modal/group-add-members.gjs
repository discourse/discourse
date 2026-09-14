import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { extractError } from "discourse/lib/ajax-error";
import { emailValid } from "discourse/lib/utilities";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import UserChooser from "discourse/select-kit/components/user-chooser";
import { not, or } from "discourse/truth-helpers";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class GroupAddMembers extends Component {
  @service currentUser;
  @service router;

  @tracked loading = false;
  @tracked setOwner = false;
  @tracked notifyUsers = true;
  @tracked usernamesAndEmails = [];
  @tracked flash;

  get title() {
    return i18n("groups.add_members.title", {
      group_name: this.args.model.fullName || this.args.model.name,
    });
  }

  get usernames() {
    return this.usernamesAndEmails
      .filter((item) => !emailValid(item))
      .join(",");
  }

  get emails() {
    return this.usernamesAndEmails.filter(emailValid).join(",");
  }

  @action
  setUsernamesAndEmails(usernamesAndEmails) {
    this.usernamesAndEmails = usernamesAndEmails;
    if (this.emails) {
      this.setOwner = false;
    }
  }

  @action
  async addMembers() {
    if (isEmpty(this.usernamesAndEmails)) {
      return;
    }

    this.loading = true;

    try {
      if (this.setOwner) {
        await this.args.model.addOwners(this.usernames, true, this.notifyUsers);
      } else {
        await this.args.model.addMembers(
          this.usernames,
          true,
          this.notifyUsers,
          this.emails
        );
      }

      this.router.transitionTo("group.members", this.args.model.name, {
        queryParams: { ...(this.usernames && { filter: this.usernames }) },
      });
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    } finally {
      this.loading = false;
    }
  }

  <template>
    <DModal
      class="group-add-members-modal"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @title={{this.title}}
    >
      <:body>
        <form class="form-vertical group-add-members">
          <p>{{i18n
              (if
                this.currentUser.can_invite_to_forum
                "groups.add_members.description"
                "groups.add_members.description_usernames_only"
              )
            }}</p>
          <div class="input-group">
            {{#if this.currentUser.can_invite_to_forum}}
              <EmailGroupUserChooser
                @onChange={{this.setUsernamesAndEmails}}
                @options={{hash
                  allowEmails=true
                  filterPlaceholder="groups.add_members.usernames_or_emails_placeholder"
                }}
                @value={{this.usernamesAndEmails}}
              />
            {{else}}
              <UserChooser
                @onChange={{this.setUsernamesAndEmails}}
                @options={{hash
                  filterPlaceholder="groups.add_members.usernames_placeholder"
                }}
                @value={{this.usernamesAndEmails}}
              />
            {{/if}}
          </div>

          {{#if @model.can_admin_group}}
            <div class="input-group">
              <label>
                <Input
                  disabled={{this.emails}}
                  id="set-owner"
                  @checked={{this.setOwner}}
                  @type="checkbox"
                />
                {{i18n "groups.add_members.set_owner"}}
              </label>
            </div>
          {{/if}}

          <div class="input-group">
            <label>
              <Input @checked={{this.notifyUsers}} @type="checkbox" />
              {{i18n "groups.add_members.notify_users"}}
            </label>
          </div>
        </form>
      </:body>
      <:footer>
        <DButton
          class="add btn-primary"
          @action={{this.addMembers}}
          @disabled={{or this.loading (not this.usernamesAndEmails)}}
          @icon="plus"
          @label="groups.add"
        />
      </:footer>
    </DModal>
  </template>
}
