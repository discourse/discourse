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
      class={{@class}}
      @name="join_method"
      @onChange={{@onChange}}
      @selection={{@selection}}
      @value={{@value}}
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
              @class="group-form-public-admission"
              @label={{i18n "groups.manage.membership.join_method.free"}}
              @onChange={{fn this.setJoinMethod "free"}}
              @selection={{this.joinMethod}}
              @value="free"
            />

            <JoinMethodOption
              @class="group-form-allow-membership-requests"
              @label={{i18n "groups.manage.membership.join_method.request"}}
              @onChange={{fn this.setJoinMethod "request"}}
              @selection={{this.joinMethod}}
              @value="request"
            />
          {{/unless}}

          <JoinMethodOption
            @class="group-form-invite-only"
            @label={{i18n "groups.manage.membership.join_method.invite"}}
            @onChange={{fn this.setJoinMethod "invite"}}
            @selection={{this.joinMethod}}
            @value="invite"
          />

          {{#if this.model.allow_membership_requests}}
            <div class="groups-form-membership-request-template">
              <label for="membership-request-template">
                {{i18n "groups.membership_request_template"}}
              </label>

              <DExpandingTextArea
                class="group-form-membership-request-template input-xxlarge"
                name="membership-request-template"
                value={{this.model.membership_request_template}}
                {{on
                  "input"
                  (withEventValue
                    (fn (mut this.model.membership_request_template))
                  )
                }}
              />
            </div>
          {{/if}}
        </fieldset>

        <label class="group-form-public-exit-label">
          <Input
            class="group-form-public-exit"
            @checked={{this.model.public_exit}}
            @type="checkbox"
          />

          {{i18n "groups.public_exit"}}
        </label>

        {{#if this.canAdminGroup}}
          <label class="groups-form-visibility-label">
            {{i18n "admin.groups.manage.interaction.visibility_levels.title"}}
          </label>

          <ComboBox
            class="groups-form-visibility-level"
            @content={{this.groupVisibilityLevelOptions}}
            @name="alias"
            @onChange={{fn (mut this.model.visibility_level)}}
            @options={{hash castInteger=true}}
            @value={{this.model.visibility_level}}
            @valueProperty="value"
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
            class="groups-form-members-visibility-level"
            @content={{this.visibilityLevelOptions}}
            @name="alias"
            @onChange={{fn (mut this.model.members_visibility_level)}}
            @value={{this.membersVisibilityLevel}}
            @valueProperty="value"
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
            class="group-form-automatic-membership-automatic"
            @choices={{this.emailDomains}}
            @name="automatic_membership"
            @nameProperty={{null}}
            @onChange={{this.onChangeEmailDomainsSetting}}
            @options={{hash allowAny=true}}
            @settingName="name"
            @value={{this.emailDomains}}
            @valueProperty={{null}}
          />

          <div class="control-instructions">
            {{i18n
              "admin.groups.manage.membership.automatic_membership_email_domains_instructions"
            }}
          </div>

          {{#if this.showAssociatedGroups}}
            <label for="automatic_membership_associated_groups">
              {{i18n
                "admin.groups.manage.membership.automatic_membership_associated_groups"
              }}
            </label>

            <ListSetting
              class="group-form-automatic-membership-associated-groups"
              @choices={{this.associatedGroups}}
              @name="automatic_membership_associated_groups"
              @nameProperty="label"
              @onChange={{fn (mut this.model.associated_group_ids)}}
              @settingName="name"
              @value={{this.model.associatedGroupIds}}
              @valueProperty="id"
            />
          {{/if}}
        </div>

        <span>
          <PluginOutlet
            @connectorTagName="div"
            @name="groups-form-membership-below-automatic"
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
            class="groups-form-grant-trust-level"
            @content={{this.trustLevelOptions}}
            @name="grant_trust_level"
            @onChange={{fn (mut this.model.grant_trust_level)}}
            @value={{this.groupTrustLevel}}
            @valueProperty="value"
          />
          <label>
            <Input
              class="groups-form-primary-group"
              @checked={{this.model.primary_group}}
              @type="checkbox"
            />

            {{i18n "admin.groups.manage.membership.primary_group"}}
          </label>
        </div>

        <div class="control-group">
          <label class="control-label" for="title">
            {{i18n "admin.groups.default_title"}}
          </label>

          <Input
            class="input-xxlarge"
            name="title"
            @value={{this.model.title}}
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
