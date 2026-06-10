/* eslint-disable ember/no-classic-components */
import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { tagName } from "@ember-decorators/component";
import GroupFlairInputs from "discourse/components/group-flair-inputs";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import AssociatedGroup from "discourse/models/associated-group";
import ComboBox from "discourse/select-kit/components/combo-box";
import ListSetting from "discourse/select-kit/components/list-setting";
import DExpandingTextArea from "discourse/ui-kit/d-expanding-text-area";
import DRadioButton from "discourse/ui-kit/d-radio-button";
import { i18n } from "discourse-i18n";

const JoinMethodOption = <template>
  <label class="radio">
    <DRadioButton
      @name="join_method"
      @value={{@value}}
      @selection={{@selection}}
      @onChange={{@onChange}}
      class={{@class}}
    />

    {{@label}}
  </label>
</template>;

@tagName("")
export default class GroupsFormMembershipFields extends Component {
  tokenSeparator = "|";

  trustLevelOptions = [
    {
      name: i18n("admin.groups.manage.membership.trust_levels_none"),
      value: 0,
    },
    { name: 1, value: 1 },
    { name: 2, value: 2 },
    { name: 3, value: 3 },
    { name: 4, value: 4 },
  ];

  visibilityLevelOptions = [
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.public"),
      value: 0,
    },
    {
      name: i18n(
        "admin.groups.manage.interaction.visibility_levels.logged_on_users"
      ),
      value: 1,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.members"),
      value: 2,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.staff"),
      value: 3,
    },
    {
      name: i18n("admin.groups.manage.interaction.visibility_levels.owners"),
      value: 4,
    },
  ];

  init() {
    super.init(...arguments);

    if (this.showAssociatedGroups) {
      this.loadAssociatedGroups();
    }
  }

  @computed("site.can_associate_groups")
  get showAssociatedGroups() {
    return this.site?.can_associate_groups;
  }

  @computed("model.automatic")
  get canEdit() {
    return !this.model?.automatic;
  }

  @computed(
    "model.isCreated",
    "model.can_admin_group",
    "currentUser.can_create_group"
  )
  get canAdminGroup() {
    return (
      (!this.model?.isCreated && this.currentUser?.can_create_group) ||
      (this.model?.isCreated && this.model?.can_admin_group)
    );
  }

  @computed(
    "model.members_visibility_level",
    "visibilityLevelOptions.firstObject.value"
  )
  get membersVisibilityLevel() {
    return (
      this.model?.members_visibility_level ||
      this.visibilityLevelOptions?.firstObject?.value
    );
  }

  @computed("membersVisibilityLevel")
  get membersVisibilityPrivate() {
    return (
      this.membersVisibilityLevel !==
      this.visibilityLevelOptions.firstObject.value
    );
  }

  @computed("model.grant_trust_level", "trustLevelOptions")
  get groupTrustLevel() {
    return (
      this.model.get("grant_trust_level") ||
      this.trustLevelOptions.firstObject.value
    );
  }

  @computed("model.public_admission", "model.allow_membership_requests")
  get joinMethod() {
    if (this.model?.public_admission) {
      return "free";
    } else if (this.model?.allow_membership_requests) {
      return "request";
    }
    return "invite";
  }

  @computed("joinMethod")
  get joinRequiresVisibility() {
    return this.joinMethod !== "invite";
  }

  // Non-admins can't edit visibility, so when the group isn't visible the only
  // valid join method is invite-only — hide the options that need visibility.
  @computed("canAdminGroup", "model.visibility_level")
  get restrictToInviteOnly() {
    return (
      !this.canAdminGroup && parseInt(this.model?.visibility_level, 10) > 1
    );
  }

  // "Who can see this group?" can't be more private than the join method allows,
  // so the restricted levels are dropped when joining doesn't require an invite.
  @computed("joinRequiresVisibility", "visibilityLevelOptions")
  get groupVisibilityLevelOptions() {
    if (this.joinRequiresVisibility) {
      return this.visibilityLevelOptions.filter((option) => option.value <= 1);
    }

    return this.visibilityLevelOptions;
  }

  @computed("model.emailDomains")
  get emailDomains() {
    return this.model.emailDomains.split(this.tokenSeparator).filter(Boolean);
  }

  loadAssociatedGroups() {
    AssociatedGroup.list().then((ags) => this.set("associatedGroups", ags));
  }

  @action
  setJoinMethod(value) {
    this.model.set("public_admission", value === "free");
    this.model.set("allow_membership_requests", value === "request");

    // Free/request require a visible group, so open up a restricted visibility.
    if (
      this.canAdminGroup &&
      value !== "invite" &&
      parseInt(this.model?.visibility_level, 10) > 1
    ) {
      this.model.set("visibility_level", 0);
    }
  }

  @action
  onChangeEmailDomainsSetting(value) {
    this.set(
      "model.automatic_membership_email_domains",
      value.join(this.tokenSeparator)
    );
  }

  <template>
    <div ...attributes>
      <div class="control-group groups-form-visibility-access">
        <label class="control-label">
          {{i18n "groups.manage.membership.visibility_and_access"}}
        </label>

        <fieldset class="groups-form-join-method">
          <legend>{{i18n "groups.manage.membership.join_method_title"}}</legend>

          {{#unless this.restrictToInviteOnly}}
            <JoinMethodOption
              @value="free"
              @label={{i18n "groups.manage.membership.join_method.free"}}
              @class="group-form-public-admission"
              @selection={{this.joinMethod}}
              @onChange={{fn this.setJoinMethod "free"}}
            />

            <JoinMethodOption
              @value="request"
              @label={{i18n "groups.manage.membership.join_method.request"}}
              @class="group-form-allow-membership-requests"
              @selection={{this.joinMethod}}
              @onChange={{fn this.setJoinMethod "request"}}
            />
          {{/unless}}

          <JoinMethodOption
            @value="invite"
            @label={{i18n "groups.manage.membership.join_method.invite"}}
            @class="group-form-invite-only"
            @selection={{this.joinMethod}}
            @onChange={{fn this.setJoinMethod "invite"}}
          />

          {{#if this.model.allow_membership_requests}}
            <div class="groups-form-membership-request-template">
              <label for="membership-request-template">
                {{i18n "groups.membership_request_template"}}
              </label>

              <DExpandingTextArea
                {{on
                  "input"
                  (withEventValue
                    (fn (mut this.model.membership_request_template))
                  )
                }}
                value={{this.model.membership_request_template}}
                name="membership-request-template"
                class="group-form-membership-request-template input-xxlarge"
              />
            </div>
          {{/if}}
        </fieldset>

        <label class="group-form-public-exit-label">
          <Input
            @type="checkbox"
            class="group-form-public-exit"
            @checked={{this.model.public_exit}}
          />

          {{i18n "groups.public_exit"}}
        </label>

        {{#if this.canAdminGroup}}
          <label class="groups-form-visibility-label">
            {{i18n "admin.groups.manage.interaction.visibility_levels.title"}}
          </label>

          <ComboBox
            @name="alias"
            @valueProperty="value"
            @value={{this.model.visibility_level}}
            @content={{this.groupVisibilityLevelOptions}}
            @onChange={{fn (mut this.model.visibility_level)}}
            @options={{hash castInteger=true}}
            class="groups-form-visibility-level"
          />

          <div class="control-instructions">
            {{i18n
              "admin.groups.manage.interaction.visibility_levels.description"
            }}
          </div>

          <label class="groups-form-members-visibility-label">
            {{i18n
              "admin.groups.manage.interaction.members_visibility_levels.title"
            }}
          </label>

          <ComboBox
            @name="alias"
            @valueProperty="value"
            @value={{this.membersVisibilityLevel}}
            @content={{this.visibilityLevelOptions}}
            @onChange={{fn (mut this.model.members_visibility_level)}}
            class="groups-form-members-visibility-level"
          />

          {{#if this.membersVisibilityPrivate}}
            <div class="control-instructions">
              {{i18n
                "admin.groups.manage.interaction.members_visibility_levels.description"
              }}
            </div>
          {{/if}}
        {{/if}}
      </div>

      {{#if this.model.can_admin_group}}
        <div class="control-group">
          <label class="control-label">{{i18n
              "admin.groups.manage.membership.automatic"
            }}</label>

          <label for="automatic_membership">
            {{i18n
              "admin.groups.manage.membership.automatic_membership_email_domains"
            }}
          </label>

          <ListSetting
            @name="automatic_membership"
            @value={{this.emailDomains}}
            @choices={{this.emailDomains}}
            @settingName="name"
            @nameProperty={{null}}
            @valueProperty={{null}}
            @onChange={{this.onChangeEmailDomainsSetting}}
            @options={{hash allowAny=true}}
            class="group-form-automatic-membership-automatic"
          />

          {{#if this.showAssociatedGroups}}
            <label for="automatic_membership_associated_groups">
              {{i18n
                "admin.groups.manage.membership.automatic_membership_associated_groups"
              }}
            </label>

            <ListSetting
              @name="automatic_membership_associated_groups"
              @value={{this.model.associatedGroupIds}}
              @choices={{this.associatedGroups}}
              @settingName="name"
              @nameProperty="label"
              @valueProperty="id"
              @onChange={{fn (mut this.model.associated_group_ids)}}
              class="group-form-automatic-membership-associated-groups"
            />
          {{/if}}
        </div>

        <span>
          <PluginOutlet
            @name="groups-form-membership-below-automatic"
            @connectorTagName="div"
            @outletArgs={{lazyHash model=this.model}}
          />
        </span>

        <div class="control-group">
          <label class="control-label">{{i18n
              "admin.groups.manage.membership.effects"
            }}</label>
          <label for="grant_trust_level">{{i18n
              "admin.groups.manage.membership.trust_levels_title"
            }}</label>

          <ComboBox
            @name="grant_trust_level"
            @valueProperty="value"
            @value={{this.groupTrustLevel}}
            @content={{this.trustLevelOptions}}
            @onChange={{fn (mut this.model.grant_trust_level)}}
            class="groups-form-grant-trust-level"
          />
          <label>
            <Input
              @type="checkbox"
              @checked={{this.model.primary_group}}
              class="groups-form-primary-group"
            />

            {{i18n "admin.groups.manage.membership.primary_group"}}
          </label>
        </div>

        <div class="control-group">
          <label class="control-label" for="title">
            {{i18n "admin.groups.default_title"}}
          </label>

          <Input
            @value={{this.model.title}}
            name="title"
            class="input-xxlarge"
          />

          <div class="control-instructions">
            {{i18n "admin.groups.default_title_description"}}
          </div>
        </div>
      {{/if}}

      {{#if this.canEdit}}
        <div class="control-group">
          <GroupFlairInputs @model={{this.model}} />
        </div>

      {{/if}}
    </div>
  </template>
}
