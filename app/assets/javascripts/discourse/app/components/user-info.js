import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNameBindings: [":user-info", "size"],
  attributeBindings: ["data-username"],
  size: "small",
  "data-username": alias("user.username"),
  includeLink: true,
  includeAvatar: true,

  didInsertElement() {
    this._super(...arguments);
    this.user?.statusManager?.trackStatus();
  },

  willDestroyElement() {
    this._super(...arguments);
    this.user?.statusManager?.stopTrackingStatus();
  },

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  },

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  },
});
