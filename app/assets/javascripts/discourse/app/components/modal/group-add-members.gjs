import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { Input } from "@ember/component";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import { isEmpty } from "@ember/utils";
import { and, not, or } from "truth-helpers";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import { emailValid } from "discourse/lib/utilities";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";

export default class GroupAddMembers extends Component {
  @service currentUser;
  @service router;

  @tracked loading = false;
  @tracked setOwner = false;
  @tracked notifyUsers = false;
  @tracked usernamesAndEmails = [];
  @tracked flash;

  get title() {
    return i18n("groups.add_members.title", {
      group_name: this.args.model.fullName || this.args.model.name,
    });
  }

  get usernames() {
    return this.usernamesAndEmails.reject(emailValid).join(",");
  }

  get emails() {
    return this.usernamesAndEmails.filter(emailValid).join(",");
  }

  @action
  setUsernamesAndEmails(usernamesAndEmails) {
    this.usernamesAndEmails = usernamesAndEmails;
    if (this.emails) {
      if (!this.usernames) {
        this.notifyUsers = false;
      }
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
      @title={{this.title}}
      @closeModal={{@closeModal}}
      class="group-add-members-modal"
      @flash={{this.flash}}
    >
      <:body>
        <form class="form-vertical group-add-members">
          <p>{{i18n "groups.add_members.description"}}</p>
          <div class="input-group">
            <EmailGroupUserChooser
              @value={{this.usernamesAndEmails}}
              @onChange={{this.setUsernamesAndEmails}}
              @options={{hash
                allowEmails=this.currentUser.can_invite_to_forum
                filterPlaceholder=(if
                  this.currentUser.can_invite_to_forum
                  "groups.add_members.usernames_or_emails_placeholder"
                  "groups.add_members.usernames_placeholder"
                )
              }}
            />
          </div>

          {{#if @model.can_admin_group}}
            <div class="input-group">
              <label>
                <Input
                  id="set-owner"
                  @type="checkbox"
                  @checked={{this.setOwner}}
                  disabled={{this.emails}}
                />
                {{i18n "groups.add_members.set_owner"}}
              </label>
            </div>
          {{/if}}

          <div class="input-group">
            <label>
              <Input
                @type="checkbox"
                @checked={{this.notifyUsers}}
                disabled={{and (not this.usernames) this.emails}}
              />
              {{i18n "groups.add_members.notify_users"}}
            </label>
          </div>
        </form>
      </:body>
      <:footer>
        <DButton
          @action={{this.addMembers}}
          class="add btn-primary"
          @icon="plus"
          @disabled={{or this.loading (not this.usernamesAndEmails)}}
          @label="groups.add"
        />
      </:footer>
    </DModal>
  </template>
}
