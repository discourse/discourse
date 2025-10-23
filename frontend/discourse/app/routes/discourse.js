import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { once } from "@ember/runloop";
import { service } from "@ember/service";
import { seenUser } from "discourse/lib/user-presence";

export default class DiscourseRoute extends Route {
  @service currentUser;

  willTransition() {
    seenUser();
  }

  _refreshTitleOnce() {
    this.send("_collectTitleTokens", []);
  }

  @action
  _collectTitleTokens(tokens) {
    // If there's a title token method, call it and get the token
    if (this.titleToken) {
      const t = this.titleToken();
      if (t?.length) {
        if (t instanceof Array) {
          t.forEach((ti) => tokens.push(ti));
        } else {
          tokens.push(t);
        }
      }
    }
    return true;
  }

  @action
  refreshTitle() {
    once(this, this._refreshTitleOnce);
  }

  isCurrentUser(user) {
    if (!this.currentUser) {
      return false; // the current user is anonymous
    }

    return user.id === this.currentUser.id;
  }
}
