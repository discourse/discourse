import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import getURL from "discourse-common/lib/get-url";
import discourseComputed from "discourse-common/utils/decorators";

@classNames("google-search-form")
@classNameBindings("hidden:hidden")
export default class GoogleSearch extends Component {
  @alias("siteSettings.login_required") hidden;

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }
}
