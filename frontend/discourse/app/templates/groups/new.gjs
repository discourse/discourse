import { hash } from "@ember/helper";
import { LinkTo } from "@ember/routing";
import GroupFlairVisibilityWarning from "discourse/components/group-flair-visibility-warning";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";
import GroupsFormMembershipFields from "discourse/components/groups-form-membership-fields";
import GroupsFormProfileFields from "discourse/components/groups-form-profile-fields";
import bodyClass from "discourse/helpers/body-class";
import EmailGroupUserChooser from "discourse/select-kit/components/email-group-user-chooser";
import DButton from "discourse/ui-kit/d-button";
import DSelectUser from "discourse/ui-kit/select/recipes/users/d-select-user";
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
          <label
            class="control-label"
            for="owner-selector"
            id="owner-selector-label"
          >{{i18n "admin.groups.add_owners"}}</label>

          {{! TODO (select-kit-replacement-cleanup): Keep the picker switch until rollout completes. }}
          {{#if @controller.siteSettings.enable_new_select_controls}}
            <DSelectUser
              class="input-xxlarge"
              @ariaLabelledBy="owner-selector-label"
              @id="owner-selector"
              @multiple={{true}}
              @onChange={{@controller.updateOwnerUsernames}}
              @texts={{hash
                placeholder=(i18n "groups.selector_placeholder")
                searchPlaceholder=(i18n "groups.selector_placeholder")
              }}
              @value={{@controller.splitOwnerUsernames}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy picker after rollout. }}
            <EmailGroupUserChooser
              class="input-xxlarge"
              @id="owner-selector"
              @onChange={{@controller.updateOwnerUsernames}}
              @options={{hash filterPlaceholder="groups.selector_placeholder"}}
              @value={{@controller.splitOwnerUsernames}}
            />
          {{/if}}
        </div>

        <div class="control-group">
          <label
            class="control-label"
            for="member-selector"
            id="member-selector-label"
          >{{i18n "groups.members.title"}}</label>

          {{! TODO (select-kit-replacement-cleanup): Keep the picker switch until rollout completes. }}
          {{#if @controller.siteSettings.enable_new_select_controls}}
            <DSelectUser
              class="input-xxlarge"
              @ariaLabelledBy="member-selector-label"
              @id="member-selector"
              @multiple={{true}}
              @onChange={{@controller.updateUsernames}}
              @texts={{hash
                placeholder=(i18n "groups.selector_placeholder")
                searchPlaceholder=(i18n "groups.selector_placeholder")
              }}
              @value={{@controller.splitUsernames}}
            />
          {{else}}
            {{! TODO (select-kit-replacement-cleanup): Remove the legacy picker after rollout. }}
            <EmailGroupUserChooser
              class="input-xxlarge"
              @id="member-selector"
              @onChange={{@controller.updateUsernames}}
              @options={{hash filterPlaceholder="groups.selector_placeholder"}}
              @value={{@controller.splitUsernames}}
            />
          {{/if}}
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
