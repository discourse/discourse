import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { once } from "@ember/runloop";
import { service } from "discourse/lib/service";
import { seenUser } from "discourse/lib/user-presence";
import CurrentUserService from "discourse/services/current-user";

export default class DiscourseRoute extends Route {
  @service(() => CurrentUserService) currentUser;

  willTransition() {
    seenUser();
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
}
