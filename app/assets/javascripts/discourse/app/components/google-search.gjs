import Component from "@ember/component";
import { alias } from "@ember/object/computed";
import { classNameBindings, classNames } from "@ember-decorators/component";
import discourseComputed from "discourse/lib/decorators";
import getURL from "discourse/lib/get-url";

@classNames("google-search-form")
@classNameBindings("hidden:hidden")
export default class GoogleSearch extends Component {
  @alias("siteSettings.login_required") hidden;

  @discourseComputed
  siteUrl() {
    return `${location.protocol}//${location.host}${getURL("/")}`;
  }
}
