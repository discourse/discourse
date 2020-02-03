import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";
import { computed } from "@ember/object";

export default Component.extend({
  tokenSeparator: "|",

  init() {
    this._super(...arguments);

    this.trustLevelOptions = [
      {
        name: I18n.t("admin.groups.manage.membership.trust_levels_none"),
        value: 0
      },
      { name: 1, value: 1 },
      { name: 2, value: 2 },
      { name: 3, value: 3 },
      { name: 4, value: 4 }
    ];
  },

  groupTrustLevel: computed(
    "model.grant_trust_level",
    "trustLevelOptions",
    function() {
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

  actions: {
    onChangeEmailDomainsSetting(value) {
      this.set("model.emailDomains", value.join(this.tokenSeparator));
    }
  }
});
