import discourseComputed from "discourse-common/utils/decorators";
import { alias } from "@ember/object/computed";
import Component from "@ember/component";

export default Component.extend({
  classNames: ["google-search-form"],
  classNameBindings: ["hidden:hidden"],

  hidden: alias("siteSettings.login_required"),

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${Discourse.getURL("/")}`;
  }
});
