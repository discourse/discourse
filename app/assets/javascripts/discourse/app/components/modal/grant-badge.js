import { action } from "@ember/object";
import Component from "@ember/component";
import Badge from "discourse/models/badge";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import I18n from "I18n";
import UserBadge from "discourse/models/user-badge";
import { all } from "rsvp";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";

export default class GrantBadgeModal extends Component.extend(
  GrantBadgeController
) {
  loading = true;
  saving = false;
  selectedBadgeId = null;

  init() {
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
    super.init(...arguments);
    this.allBadges = [];
    this.userBadges = [];
  }

  @discourseComputed("model.selectedPost")
  post() {
    return this.get("model.selectedPost");
  }

  @discourseComputed("post")
  badgeReason(post) {
    return getURL(post.get("url"));
  }

  @discourseComputed("saving", "selectedBadgeGrantable")
  buttonDisabled(saving, selectedBadgeGrantable) {
    return saving || !selectedBadgeGrantable;
  }

  @action
  performGrantBadge() {
    this.set("saving", true);

    this.grantBadge(
      this.selectedBadgeId,
      this.get("post.username"),
      this.badgeReason
    )
      .then(
        (newBadge) => {
          this.set("selectedBadgeId", null);
          this.setProperties({
            flash: I18n.t("badges.successfully_granted", {
              username: this.get("post.username"),
              badge: newBadge.get("badge.name"),
            }),
            flashType: "success",
          });
        },
        (e) => {
          this.setProperties({
            flash: extractError(e),
            flashType: "error",
          });
        }
      )
      .finally(() => this.set("saving", false));
  }
}
