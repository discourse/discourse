import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";
import { propertyEqual } from "discourse/lib/computed";

export default Component.extend({
  classNameBindings: [":user-stream-item", ":item", "moderatorAction"],

  @discourseComputed("post.url")
  postUrl(url) {
    return getURL(url);
  },
  moderatorAction: propertyEqual(
    "post.post_type",
    "site.post_types.moderator_action"
  ),
});
