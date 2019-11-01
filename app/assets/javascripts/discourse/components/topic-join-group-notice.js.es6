import Component from "@ember/component";
import { default as computed } from "ember-addons/ember-computed-decorators";

export default Component.extend({
  classNames: ["topic-notice"],

  @computed("model.group.{full_name,name,allow_membership_requests}")
  accessViaGroupText(group) {
    const name = group.full_name || group.name;
    const suffix = group.allow_membership_requests ? "request" : "join";
    return I18n.t(`topic.group_${suffix}`, { name });
  },

  @computed("model.group.allow_membership_requests")
  accessViaGroupButtonText(allowRequest) {
    return `groups.${allowRequest ? "request" : "join"}`;
  }
});
