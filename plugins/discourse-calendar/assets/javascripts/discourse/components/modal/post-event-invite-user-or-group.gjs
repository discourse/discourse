import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import { i18n } from "discourse-i18n";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import EventField from "../event-field";

export default class PostEventInviteUserOrGroup extends Component {
  @tracked invitedNames = [];
  @tracked flash = null;

  @action
  async invite() {
    try {
      await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/invite.json`,
        {
          data: { invites: this.invitedNames },
          type: "POST",
        }
      );
      this.args.closeModal();
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_post_event.invite_user_or_group.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
    >
      <:body>
        <form>
          <EventField>
            <EmailGroupUserChooser
              @value={{this.invitedNames}}
              @options={{hash
                fullWidthWrap=true
                includeMessageableGroups=true
                filterPlaceholder="composer.users_placeholder"
                excludeCurrentUser=true
              }}
            />
          </EventField>
        </form>
      </:body>
      <:footer>
        <DButton
          @type="button"
          class="btn-primary"
          @label="discourse_post_event.invite_user_or_group.invite"
          @action={{this.invite}}
        />
      </:footer>
    </DModal>
  </template>
}
