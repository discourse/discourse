import Component from "@ember/component";
import { classNameBindings } from "@ember-decorators/component";
import { propertyEqual } from "discourse/lib/computed";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { userPath } from "discourse/lib/url";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import { i18n } from "discourse-i18n";

@classNameBindings(
  ":user-stream-item",
  ":item",
  "moderatorAction",
  "primaryGroup"
)
export default class GroupPost extends Component {
  @propertyEqual("post.post_type", "site.post_types.moderator_action")
  moderatorAction;

  @discourseComputed("post.url")
  postUrl(url) {
    return getURL(url);
  }

  @discourseComputed("post.user")
  name(postUser) {
    if (prioritizeNameInUx(postUser.name)) {
      return postUser.name;
    }
    return postUser.username;
  }

  @discourseComputed("post.user")
  primaryGroup(postUser) {
    if (postUser.primary_group_name) {
      return `group-${postUser.primary_group_name}`;
    }
  }

  @discourseComputed("post.user.username")
  userUrl(username) {
    return userPath(username.toLowerCase());
  }

  @discourseComputed("post.title", "post.post_number")
  titleAriaLabel(title, postNumber) {
    return i18n("groups.aria_post_number", { postNumber, title });
  }
}
