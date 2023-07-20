import Component from "@glimmer/component";
import { userPath } from "discourse/lib/url";

export default class ChatUserInfo extends Component {
  get userPath() {
    return userPath(this.args.user.username);
  }
}
