import Component, { Input } from "@ember/component";
import { fn, hash } from "@ember/helper";
import { on } from "@ember/modifier";
import { action, computed } from "@ember/object";
import { not, readOnly } from "@ember/object/computed";
import ExpandingTextArea from "discourse/components/expanding-text-area";
import GroupFlairInputs from "discourse/components/group-flair-inputs";
import PluginOutlet from "discourse/components/plugin-outlet";
import lazyHash from "discourse/helpers/lazy-hash";
import withEventValue from "discourse/helpers/with-event-value";
import discourseComputed from "discourse/lib/decorators";
import AssociatedGroup from "discourse/models/associated-group";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";
import ListSetting from "select-kit/components/list-setting";

export default class GroupsFormMembershipFields extends Component {
  tokenSeparator = "|";

  @readOnly("site.can_associate_groups") showAssociatedGroups;
  @not("model.automatic") canEdit;

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

  init() {
    super.init(...arguments);

    if (this.showAssociatedGroups) {
      this.loadAssociatedGroups();
    }
  }

  @computed("model.grant_trust_level", "trustLevelOptions")
  get groupTrustLevel() {
    return (
      this.model.get("grant_trust_level") ||
      this.trustLevelOptions.firstObject.value
    );
  }

  @discourseComputed("model.visibility_level", "model.public_admission")
  disableMembershipRequestSetting(visibility_level, publicAdmission) {
    visibility_level = parseInt(visibility_level, 10);
    return publicAdmission || visibility_level > 1;
  }

  @discourseComputed(
    "model.visibility_level",
    "model.allow_membership_requests"
  )
  disablePublicSetting(visibility_level, allowMembershipRequests) {
    visibility_level = parseInt(visibility_level, 10);
    return allowMembershipRequests || visibility_level > 1;
  }

  @computed("model.emailDomains")
  get emailDomains() {
    return this.model.emailDomains.split(this.tokenSeparator).filter(Boolean);
  }

  loadAssociatedGroups() {
    AssociatedGroup.list().then((ags) => this.set("associatedGroups", ags));
  }

  @action
  onChangeEmailDomainsSetting(value) {
    this.set(
      "model.automatic_membership_email_domains",
      value.join(this.tokenSeparator)
    );
  }

  <template>
    <div class="control-group">
      <label class="control-label">{{i18n
          "groups.manage.membership.access"
        }}</label>

      <label>
        <Input
          @type="checkbox"
          class="group-form-public-admission"
          @checked={{this.model.public_admission}}
          disabled={{this.disablePublicSetting}}
        />

        {{i18n "groups.public_admission"}}
      </label>

      <label>
        <Input
          @type="checkbox"
          class="group-form-public-exit"
          @checked={{this.model.public_exit}}
        />

        {{i18n "groups.public_exit"}}
      </label>

      <label>
        <Input
          @type="checkbox"
          class="group-form-allow-membership-requests"
          @checked={{this.model.allow_membership_requests}}
          disabled={{this.disableMembershipRequestSetting}}
        />

        {{i18n "groups.allow_membership_requests"}}
      </label>

      {{#if this.model.allow_membership_requests}}
        <div>
          <label for="membership-request-template">
            {{i18n "groups.membership_request_template"}}
          </label>

          <ExpandingTextArea
            {{on
              "input"
              (withEventValue (fn (mut this.model.membership_request_template)))
            }}
            value={{this.model.membership_request_template}}
            name="membership-request-template"
            class="group-form-membership-request-template input-xxlarge"
          />
        </div>
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

        <Input @value={{this.model.title}} name="title" class="input-xxlarge" />

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
  </template>
}
