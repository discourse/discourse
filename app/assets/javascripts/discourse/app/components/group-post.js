import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import getURL from "discourse-common/lib/get-url";

export default Component.extend({
  @discourseComputed("post.url")
  postUrl(url) {
    return getURL(url);
  },
});
