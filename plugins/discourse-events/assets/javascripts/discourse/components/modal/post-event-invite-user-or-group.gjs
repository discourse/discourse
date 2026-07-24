import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { hash } from "@ember/helper";
import { action } from "@ember/object";
import { service } from "@ember/service";
import Form from "discourse/components/form";
import { ajax } from "discourse/lib/ajax";
import { extractError } from "discourse/lib/ajax-error";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DModal from "discourse/ui-kit/d-modal";
import { i18n } from "discourse-i18n";

export default class PostEventInviteUserOrGroup extends Component {
  @service toasts;

  @tracked flash = null;

  formApi;

  data = { invitedNames: [] };

  @action
  registerApi(api) {
    this.formApi = api;
  }

  @action
  submit() {
    this.formApi.submit();
  }

  @action
  async invite(data) {
    try {
      await ajax(
        `/discourse-post-event/events/${this.args.model.event.id}/invite.json`,
        {
          data: { invites: data.invitedNames },
          type: "POST",
        }
      );
      this.args.closeModal();
      this.toasts.success({
        duration: "short",
        data: {
          message: i18n("discourse_post_event.invite_user_or_group.success"),
        },
      });
    } catch (e) {
      this.flash = extractError(e);
    }
  }

  <template>
    <DModal
      @title={{i18n "discourse_post_event.invite_user_or_group.title"}}
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      class="post-event-invite-user-or-group"
    >
      <:body>
        <Form
          @data={{this.data}}
          @onSubmit={{this.invite}}
          @onRegisterApi={{this.registerApi}}
          as |form|
        >
          <form.Field
            @name="invitedNames"
            @title={{i18n "discourse_post_event.invite_user_or_group.title"}}
            @showTitle={{false}}
            @type="custom"
            @format="full"
            as |field|
          >
            <field.Control>
              <EmailGroupUserChooser
                @value={{field.value}}
                @onChange={{field.set}}
                @options={{hash
                  includeMessageableGroups=true
                  filterPlaceholder="composer.users_placeholder"
                  excludeCurrentUser=true
                }}
              />
            </field.Control>
          </form.Field>
        </Form>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @label="discourse_post_event.invite_user_or_group.invite"
          @action={{this.submit}}
        />
      </:footer>
    </DModal>
  </template>
}
