import Controller, { inject as controller } from "@ember/controller";
import Badge from "discourse/models/badge";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import I18n from "I18n";
import Modal from "discourse/controllers/modal";
import UserBadge from "discourse/models/user-badge";
import { all } from "rsvp";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";

export default Controller.extend(ModalFunctionality, GrantBadgeController, {
  topicController: controller("topic"),
  loading: true,
  saving: false,
  selectedBadgeId: null,

  init() {
    this._super(...arguments);

    this.allBadges = [];
    this.userBadges = [];
  },

  @discourseComputed("topicController.selectedPosts")
  post() {
    return this.get("topicController.selectedPosts")[0];
  },

  @discourseComputed("post")
  badgeReason(post) {
    const url = post.get("url");
    const protocolAndHost =
      window.location.protocol + "//" + window.location.host;

    return url.startsWith("/") ? protocolAndHost + url : url;
  },

  @discourseComputed("saving", "selectedBadgeGrantable")
  buttonDisabled(saving, selectedBadgeGrantable) {
    return saving || !selectedBadgeGrantable;
  },

  onShow() {
    this.set("loading", true);

    all([
      Badge.findAll(),
      UserBadge.findByUsername(this.get("post.username")),
    ]).then(([allBadges, userBadges]) => {
      this.setProperties({
        allBadges,
        userBadges,
        loading: false,
      });
    });
  },

  actions: {
    grantBadge() {
      this.set("saving", true);

      this.grantBadge(
        this.selectedBadgeId,
        this.get("post.username"),
        this.badgeReason
      )
        .then(
          (newBadge) => {
            this.set("selectedBadgeId", null);
            this.flash(
              I18n.t("badges.successfully_granted", {
                username: this.get("post.username"),
                badge: newBadge.get("badge.name"),
              }),
              "success"
            );
          },
          (error) => {
            this.flash(extractError(error), "error");
          }
        )
        .finally(() => this.set("saving", false));
    },
  },
});
