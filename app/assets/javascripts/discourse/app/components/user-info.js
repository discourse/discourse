import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import {
  attributeBindings,
  classNameBindings,
} from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";

@classNameBindings(":user-info", "size")
@attributeBindings("dataUsername:data-username")
export default class UserInfo extends Component {
  size = "small";
  includeLink = true;
  includeAvatar = true;

  @alias("user.username") dataUsername;

  didInsertElement() {
    super.didInsertElement(...arguments);
    this.user?.statusManager?.trackStatus();
  }

  willDestroyElement() {
    super.willDestroyElement(...arguments);
    this.user?.statusManager?.stopTrackingStatus();
  }

  @discourseComputed("user.username")
  userPath(username) {
    return userPath(username);
  }

  @discourseComputed("user.name")
  nameFirst(name) {
    return prioritizeNameInUx(name);
  }
}
