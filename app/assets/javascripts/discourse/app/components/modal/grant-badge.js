import { action } from "@ember/object";
import Component from "@ember/component";
import Badge from "discourse/models/badge";
import GrantBadgeController from "discourse/mixins/grant-badge-controller";
import I18n from "I18n";
import UserBadge from "discourse/models/user-badge";
import discourseComputed from "discourse-common/utils/decorators";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse-common/lib/get-url";

export default class GrantBadgeModal extends Component.extend(
  GrantBadgeController
) {
  loading = true;
  saving = false;
  selectedBadgeId = null;
  flash = null;
  flashType = null;
  allBadges = [];
  userBadges = [];

  @discourseComputed("model.selectedPost")
  post() {
    return this.get("model.selectedPost");
  }

  @discourseComputed("saving", "selectedBadgeGrantable")
  buttonDisabled(saving, selectedBadgeGrantable) {
    return saving || !selectedBadgeGrantable;
  }

  @action
  async loadBadges() {
    this.set("loading", true);
    try {
      const allBadges = await Badge.findAll();
      const userBadges = await UserBadge.findByUsername(
        this.get("post.username")
      );
      this.setProperties({
        allBadges,
        userBadges,
      });
    } catch (e) {
      this.setProperties({
        flash: extractError(e),
        flashType: "error",
      });
    } finally {
      this.set("loading", false);
    }
  }
  @action
  async performGrantBadge() {
    try {
      this.set("saving", true);
      const username = this.get("post.username");
      const newBadge = await this.grantBadge(
        this.selectedBadgeId,
        username,
        getURL(this.get("post.url"))
      );
      this.set("selectedBadgeId", null);
      this.setProperties({
        flash: I18n.t("badges.successfully_granted", {
          username,
          badge: newBadge.get("badge.name"),
        }),
        flashType: "success",
      });
    } catch (e) {
      this.setProperties({
        flash: extractError(e),
        flashType: "error",
      });
    } finally {
      this.set("saving", false);
    }
  }
}
