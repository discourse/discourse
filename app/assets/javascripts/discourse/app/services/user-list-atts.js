import Service from "@ember/service";
import { userPath } from "discourse/lib/url";

export default class UserListAtts extends Service {
  smallUserAtts(user) {
    return {
      template: user.avatar_template,
      username: user.username,
      post_url: user.post_url,
      url: userPath(user.username_lower),
      unknown: user.unknown,
    };
  }
}
