import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import GroupFlairVisibilityWarning from "discourse/components/group-flair-visibility-warning";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";
import GroupsFormMembershipFields from "discourse/components/groups-form-membership-fields";
import GroupsFormProfileFields from "discourse/components/groups-form-profile-fields";
import bodyClass from "discourse/helpers/body-class";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import { i18n } from "discourse-i18n";

export default <template>
  {{bodyClass "groups-new-page"}}

  <section>
    <h1>{{i18n "admin.groups.new.title"}}</h1>

    <hr />

    <form class="groups-form form-vertical">
      <GroupsFormProfileFields
        @disableSave={{@controller.saving}}
        @model={{@controller.model}}
      >
        <div class="control-group">
          <label class="control-label" for="owner-selector">{{i18n
              "admin.groups.add_owners"
            }}</label>

          <EmailGroupUserChooser
            class="input-xxlarge"
            @id="owner-selector"
            @onChange={{@controller.updateOwnerUsernames}}
            @options={{hash filterPlaceholder="groups.selector_placeholder"}}
            @value={{@controller.splitOwnerUsernames}}
          />
        </div>

        <div class="control-group">
          <label class="control-label" for="member-selector">{{i18n
              "groups.members.title"
            }}</label>

          <EmailGroupUserChooser
            class="input-xxlarge"
            @id="member-selector"
            @onChange={{@controller.updateUsernames}}
            @options={{hash filterPlaceholder="groups.selector_placeholder"}}
            @value={{@controller.splitUsernames}}
          />
        </div>
      </GroupsFormProfileFields>

      <GroupsFormMembershipFields @model={{@controller.model}} />
      <GroupsFormInteractionFields @model={{@controller.model}} />

      <GroupFlairVisibilityWarning @model={{@controller.model}} />
      <div class="control-group buttons">
        <DButton
          class="btn-primary group-form-save"
          type="submit"
          @action={{@controller.save}}
          @disabled={{@controller.saving}}
          @label="admin.groups.new.create"
        />

        <LinkTo @route="groups">
          {{i18n "cancel"}}
        </LinkTo>
      </div>
    </form>
  </section>
</template>
