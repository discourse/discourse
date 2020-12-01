import Composer from "discourse/models/composer";
import Route from "@ember/routing/route";
import { once } from "@ember/runloop";
import { seenUser } from "discourse/lib/user-presence";

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

    clearTopicDraft() {
      // perhaps re-delegate this to root controller in all cases?
      // TODO also poison the store so it does not come back from the
      // dead
      if (this.get("controller.list.draft")) {
        this.set("controller.list.draft", null);
      }

      if (this.controllerFor("discovery/categories").get("model.draft")) {
        this.controllerFor("discovery/categories").set("model.draft", null);
      }

      if (this.controllerFor("discovery/topics").get("model.draft")) {
        this.controllerFor("discovery/topics").set("model.draft", null);
      }
    },
  },

  redirectIfLoginRequired() {
    const app = this.controllerFor("application");
    if (app.get("loginRequired")) {
      this.replaceWith("login");
    }
  },

  openTopicDraft(model) {
    const composer = this.controllerFor("composer");

    if (
      composer.get("model.action") === Composer.CREATE_TOPIC &&
      composer.get("model.draftKey") === model.draft_key
    ) {
      composer.set("model.composeState", Composer.OPEN);
    } else {
      composer.open({
        action: Composer.CREATE_TOPIC,
        draft: model.draft,
        draftKey: model.draft_key,
        draftSequence: model.draft_sequence,
      });
    }
  },

  isPoppedState(transition) {
    return !transition._discourse_intercepted && !!transition.intent.url;
  },
});

export default DiscourseRoute;
