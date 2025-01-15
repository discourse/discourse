import { action } from "@ember/object";
import Route from "@ember/routing/route";
import { once } from "@ember/runloop";
import { service } from "@ember/service";
import deprecated from "discourse/lib/deprecated";
import { getOwnerWithFallback } from "discourse/lib/get-owner";
import { seenUser } from "discourse/lib/user-presence";

export default class DiscourseRoute extends Route {
  @service router;

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

  redirectIfLoginRequired() {
    const app = this.controllerFor("application");
    if (app.get("loginRequired")) {
      this.router.replaceWith("login");
    }
  }

  openTopicDraft() {
    deprecated(
      "DiscourseRoute#openTopicDraft is deprecated. Inject the composer service and call openNewTopic instead",
      { id: "discourse.open-topic-draft" }
    );
    return getOwnerWithFallback(this).lookup("service:composer").openNewTopic();
  }

  isCurrentUser(user) {
    if (!this.currentUser) {
      return false; // the current user is anonymous
    }

    return user.id === this.currentUser.id;
  }
}
