import Component from "@ember/component";
import { action, computed } from "@ember/object";
import { not, readOnly } from "@ember/object/computed";
import discourseComputed from "discourse/lib/decorators";
import AssociatedGroup from "discourse/models/associated-group";
import { i18n } from "discourse-i18n";

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
}
