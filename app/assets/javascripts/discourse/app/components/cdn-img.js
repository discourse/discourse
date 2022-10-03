import Component from "@ember/component";
import discourseComputed from "discourse-common/utils/decorators";
import { getURLWithCDN } from "discourse-common/lib/get-url";

export default Component.extend({
  tagName: "",

  @discourseComputed("src")
  cdnSrc(src) {
    return getURLWithCDN(src);
  },
});
