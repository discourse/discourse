import Component from "@ember/component";
import I18n from "I18n";
import { computed } from "@ember/object";
import { not, readOnly } from "@ember/object/computed";
import discourseComputed from "discourse-common/utils/decorators";
import AssociatedGroup from "discourse/models/associated-group";

export default Component.extend({
  tokenSeparator: "|",
  showAssociatedGroups: readOnly("site.can_associate_groups"),

  init() {
    this._super(...arguments);

    this.trustLevelOptions = [
      {
        name: I18n.t("admin.groups.manage.membership.trust_levels_none"),
        value: 0,
      },
      { name: 1, value: 1 },
      { name: 2, value: 2 },
      { name: 3, value: 3 },
      { name: 4, value: 4 },
    ];

    if (this.showAssociatedGroups) {
      this.loadAssociatedGroups();
    }
  },

  canEdit: not("model.automatic"),

  groupTrustLevel: computed(
    "model.grant_trust_level",
    "trustLevelOptions",
    function () {
      return (
        this.model.get("grant_trust_level") ||
        this.trustLevelOptions.firstObject.value
      );
    }
  ),

  @discourseComputed("model.visibility_level", "model.public_admission")
  disableMembershipRequestSetting(visibility_level, publicAdmission) {
    visibility_level = parseInt(visibility_level, 10);
    return publicAdmission || visibility_level > 1;
  },

  @discourseComputed(
    "model.visibility_level",
    "model.allow_membership_requests"
  )
  disablePublicSetting(visibility_level, allowMembershipRequests) {
    visibility_level = parseInt(visibility_level, 10);
    return allowMembershipRequests || visibility_level > 1;
  },

  emailDomains: computed("model.emailDomains", function () {
    return this.model.emailDomains.split(this.tokenSeparator).filter(Boolean);
  }),

  loadAssociatedGroups() {
    AssociatedGroup.list().then((ags) => this.set("associatedGroups", ags));
  },

  actions: {
    onChangeEmailDomainsSetting(value) {
      this.set(
        "model.automatic_membership_email_domains",
        value.join(this.tokenSeparator)
      );
    },
  },
});
