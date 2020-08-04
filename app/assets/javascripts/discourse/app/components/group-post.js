import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";
import Component from "@ember/component";

export default Component.extend({
  @discourseComputed("post.url")
  postUrl(url) {
    return getURL(url);
  }
});
