import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { prioritizeNameInUx } from "discourse/lib/settings";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  classNameBindings: [
    ":user-stream-item",
    ":item",
    "moderatorAction",
    "primaryGroup",
  ],

  @discourseComputed("post.url")
  postUrl(url) {
    return getURL(url);
  },
  moderatorAction: propertyEqual(
    "post.post_type",
    "site.post_types.moderator_action"
  ),

  @discourseComputed("post.user")
  name(postUser) {
    if (prioritizeNameInUx(postUser.name)) {
      return postUser.name;
    }
    return postUser.username;
  },

  @discourseComputed("post.user")
  primaryGroup(postUser) {
    if (postUser.primary_group_name) {
      return `group-${postUser.primary_group_name}`;
    }
  },
});
