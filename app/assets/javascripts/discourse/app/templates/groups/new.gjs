import RouteTemplate from 'ember-route-template'
import bodyClass from "discourse/helpers/body-class";
import i18n from "discourse/helpers/i18n";
import GroupsFormProfileFields from "discourse/components/groups-form-profile-fields";
import EmailGroupUserChooser from "select-kit/components/email-group-user-chooser";
import { hash } from "@ember/helper";
import GroupsFormMembershipFields from "discourse/components/groups-form-membership-fields";
import GroupsFormInteractionFields from "discourse/components/groups-form-interaction-fields";
import DButton from "discourse/components/d-button";
import { LinkTo } from "@ember/routing";
export default RouteTemplate(<template>{{bodyClass "groups-new-page"}}

<section>
  <h1>{{i18n "admin.groups.new.title"}}</h1>

  <hr />

  <form class="groups-form form-vertical">
    <GroupsFormProfileFields @model={{@controller.model}} @disableSave={{@controller.saving}}>
      <div class="control-group">
        <label class="control-label" for="owner-selector">{{i18n "admin.groups.add_owners"}}</label>

        <EmailGroupUserChooser @id="owner-selector" @value={{@controller.splitOwnerUsernames}} @onChange={{action "updateOwnerUsernames"}} @options={{hash filterPlaceholder="groups.selector_placeholder"}} class="input-xxlarge" />
      </div>

      <div class="control-group">
        <label class="control-label" for="member-selector">{{i18n "groups.members.title"}}</label>

        <EmailGroupUserChooser @id="member-selector" @value={{@controller.splitUsernames}} @onChange={{action "updateUsernames"}} @options={{hash filterPlaceholder="groups.selector_placeholder"}} class="input-xxlarge" />
      </div>
    </GroupsFormProfileFields>

    <GroupsFormMembershipFields @model={{@controller.model}} />
    <GroupsFormInteractionFields @model={{@controller.model}} />

    <div class="control-group buttons">
      <DButton @action={{@controller.save}} @disabled={{@controller.saving}} @label="admin.groups.new.create" type="submit" class="btn-primary group-form-save" />

      <LinkTo @route="groups">
        {{i18n "cancel"}}
      </LinkTo>
    </div>
  </form>
</section></template>)