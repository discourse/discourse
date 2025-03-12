import Component from "@ember/component";
import { action } from "@ember/object";
import { classNames } from "@ember-decorators/component";

@classNames("item")
export default class GroupMember extends Component {
  @action
  remove(event) {
    event?.preventDefault();
    this.removeAction(this.member);
  }
}
