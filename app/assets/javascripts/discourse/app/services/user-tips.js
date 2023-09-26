import Service, { inject as service } from "@ember/service";
import { isTesting } from "discourse-common/config/environment";
import { disableImplicitInjections } from "discourse/lib/implicit-injections";
import { next } from "@ember/runloop";
import Site from "discourse/models/site";
import { tracked } from "@glimmer/tracking";

@disableImplicitInjections
export default class UserTips extends Service {
  @service site;
  @service currentUser;

  @tracked availableTips = [];
  @tracked renderedId;

  computeRenderedId() {
    if (this.availableTips.find((tip) => tip.id === this.renderedId)) {
      return this.renderedId;
    }

    return this.availableTips
      .sortBy("priority")
      .reverse()
      .find((tip) => {
        if (this.canSeeUserTip(tip.id)) {
          return tip.id;
        }
      })?.id;
  }

  addAvailableTip(tip) {
    next(() => {
      this.availableTips = [...this.availableTips, tip];
      this.renderedId = this.computeRenderedId();
    });
  }

  removeAvailableTip(tip) {
    next(() => {
      this.availableTips = this.availableTips.filter((availableTip) => {
        return tip.id !== availableTip.id;
      });

      this.renderedId = this.computeRenderedId();
    });
  }

  canSeeUserTip(tipId) {
    if (!this.currentUser) {
      return false;
    }

    const userTips = Site.currentProp("user_tips");

    if (!userTips || this.currentUser.user_option?.skip_new_user_tips) {
      return false;
    }

    if (!userTips[tipId]) {
      if (!isTesting()) {
        // eslint-disable-next-line no-console
        console.warn("Cannot show user tip with id", tipId);
      }
      return false;
    }

    const seenUserTips = this.currentUser.user_option?.seen_popups || [];
    if (seenUserTips.includes(-1) || seenUserTips.includes(userTips[tipId])) {
      return false;
    }

    return true;
  }

  async hideUserTipForever(tipId) {
    if (!this.currentUser) {
      return;
    }

    const userTips = Site.currentProp("user_tips");
    if (!userTips || this.currentUser.user_option?.skip_new_user_tips) {
      return;
    }

    // Empty tipId means all user tips.
    if (!userTips[tipId]) {
      // eslint-disable-next-line no-console
      console.warn("Cannot hide user tip with id", tipId);
      return;
    }

    this.removeAvailableTip({ id: tipId });

    // Update list of seen user tips.
    let seenUserTips = this.currentUser.user_option?.seen_popups || [];
    if (seenUserTips.includes(userTips[tipId])) {
      return;
    }
    seenUserTips.push(userTips[tipId]);

    // Save seen user tips on the server.
    if (!this.currentUser.user_option) {
      this.currentUser.set("user_option", {});
    }
    this.currentUser.set("user_option.seen_popups", seenUserTips);
    await this.currentUser.save(["seen_popups"]);
  }
}
