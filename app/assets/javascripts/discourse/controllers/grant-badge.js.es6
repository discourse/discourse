import computed from "ember-addons/ember-computed-decorators";
import { extractError } from "discourse/lib/ajax-error";
import ModalFunctionality from "discourse/mixins/modal-functionality";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";

export default Ember.Controller.extend(
  ModalFunctionality,
  GrantBadgeController,
  {
    topicController: Ember.inject.controller("topic"),
    loading: true,
    saving: false,
    selectedBadgeId: null,
    allBadges: [],
    userBadges: [],

    @computed("topicController.selectedPosts")
    post() {
      return this.get("topicController.selectedPosts")[0];
    },

    @computed("post")
    badgeReason(post) {
      const url = post.get("url");
      const protocolAndHost =
        window.location.protocol + "//" + window.location.host;

      return url.indexOf("/") === 0 ? protocolAndHost + url : url;
    },

    @computed("saving", "selectedBadgeGrantable")
    buttonDisabled(saving, selectedBadgeGrantable) {
      return saving || !selectedBadgeGrantable;
    },

    onShow() {
      this.set("loading", true);

      Ember.RSVP.all([
        Badge.findAll(),
        UserBadge.findByUsername(this.get("post.username"))
      ]).then(([allBadges, userBadges]) => {
        this.setProperties({
          allBadges: allBadges,
          userBadges: userBadges,
          loading: false
        });
      });
    },

    actions: {
      grantBadge() {
        this.set("saving", true);

        this.grantBadge(
          this.get("selectedBadgeId"),
          this.get("post.username"),
          this.get("badgeReason")
        )
          .then(
            newBadge => {
              this.set("selectedBadgeId", null);
              this.flash(
                I18n.t("badges.successfully_granted", {
                  username: this.get("post.username"),
                  badge: newBadge.get("badge.name")
                }),
                "success"
              );
            },
            error => {
              this.flash(extractError(error), "error");
            }
          )
          .finally(() => this.set("saving", false));
      }
    }
  }
);
