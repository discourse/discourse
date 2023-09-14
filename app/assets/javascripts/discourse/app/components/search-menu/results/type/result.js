import Component from "@glimmer/component";
import DiscourseURL from "discourse/lib/url";
import { action } from "@ember/object";

export default class PostResult extends Component {
  @action
  onClick(event) {
    event.preventDefault();
    DiscourseURL.routeTo(this.args.result.url || this.args.result.path);
    this.args.closeSearchMenu();
    return false;
  }
}
