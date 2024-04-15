import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";

export default Component.extend({
  classNames: ["google-search-form"],
  classNameBindings: ["hidden:hidden"],

  hidden: alias("siteSettings.login_required"),

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  },
});
