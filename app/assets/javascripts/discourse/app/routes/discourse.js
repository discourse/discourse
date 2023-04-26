import Composer from "discourse/models/composer";
import Draft from "discourse/models/draft";
import Route from "@ember/routing/route";
import { once } from "@ember/runloop";
import { seenUser } from "discourse/lib/user-presence";
import { getOwner } from "discourse-common/lib/get-owner";

const DiscourseRoute = Route.extend({
  showFooter: false,

  willTransition() {
    seenUser();
  },

  activate() {
    this._super(...arguments);
    if (this.showFooter) {
      this.controllerFor("application").set("showFooter", true);
    }
  },

  _refreshTitleOnce() {
    this.send("_collectTitleTokens", []);
  },

  actions: {
    _collectTitleTokens(tokens) {
      // If there's a title token method, call it and get the token
      if (this.titleToken) {
        const t = this.titleToken();
        if (t && t.length) {
          if (t instanceof Array) {
            t.forEach(function (ti) {
              tokens.push(ti);
            });
          } else {
            tokens.push(t);
          }
        }
      }
      return true;
    },

    refreshTitle() {
      once(this, this._refreshTitleOnce);
    },
  },

  redirectIfLoginRequired() {
    const app = this.controllerFor("application");
    if (app.get("loginRequired")) {
      this.replaceWith("login");
    }
  },

  openTopicDraft() {
    const composer = getOwner(this).lookup("service:composer");

    if (
      composer.get("model.action") === Composer.CREATE_TOPIC &&
      composer.get("model.draftKey") === Composer.NEW_TOPIC_KEY
    ) {
      composer.set("model.composeState", Composer.OPEN);
    } else {
      Draft.get(Composer.NEW_TOPIC_KEY).then((data) => {
        if (data.draft) {
          composer.open({
            action: Composer.CREATE_TOPIC,
            draft: data.draft,
            draftKey: Composer.NEW_TOPIC_KEY,
            draftSequence: data.draft_sequence,
          });
        }
      });
    }
  },

  // deprecated, use isCurrentUser() instead
  isAnotherUsersPage(user) {
    if (!this.currentUser) {
      return true;
    }

    return user.username !== this.currentUser.username;
  },

  isCurrentUser(user) {
    if (!this.currentUser) {
      return false; // the current user is anonymous
    }

    return user.id === this.currentUser.id;
  },

  isPoppedState(transition) {
    return (
      !transition._discourse_intercepted &&
      (!!transition.intent.url || !!transition.queryParamsOnly)
    );
  },
});

export default DiscourseRoute;
