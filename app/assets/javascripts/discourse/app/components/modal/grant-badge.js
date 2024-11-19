import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { action } from "@ember/object";
import { extractError } from "discourse/lib/ajax-error";
import {
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import getURL from "discourse-common/lib/get-url";
import { i18n } from "discourse-i18n";

export default class GrantBadgeModal extends Component {
  @tracked loading = true;
  @tracked saving = false;
  @tracked selectedBadgeId = null;
  @tracked flash = null;
  @tracked flashType = null;
  @tracked allBadges = [];
  @tracked userBadges = [];
  @tracked availableBadges = [];

  get noAvailableBadges() {
    !this.availableBadges.length;
  }

  get post() {
    return this.args.model.selectedPost;
  }

  get buttonDisabled() {
    return (
      this.saving ||
      !isBadgeGrantable(this.selectedBadgeId, this.availableBadges)
    );
  }

  #updateAvailableBadges() {
    this.availableBadges = grantableBadges(this.allBadges, this.userBadges);
  }

  @action
  async loadBadges() {
    this.loading = true;
    try {
      this.allBadges = await Badge.findAll();
      this.userBadges = await UserBadge.findByUsername(this.post.username);
      this.#updateAvailableBadges();
    } catch (e) {
      this.flash = extractError(e);
      this.flashType = "error";
    } finally {
      this.loading = false;
    }
  }
  @action
  async performGrantBadge() {
    try {
      this.saving = true;
      const username = this.post.username;
      const newBadge = await UserBadge.grant(
        this.selectedBadgeId,
        username,
        getURL(this.post.url)
      );
      this.userBadges.pushObject(newBadge);
      this.#updateAvailableBadges();
      this.selectedBadgeId = null;
      this.flash = i18n("badges.successfully_granted", {
        username,
        badge: newBadge.get("badge.name"),
      });
      this.flashType = "success";
    } catch (e) {
      this.flash = extractError(e);
      this.flashType = "error";
    } finally {
      this.saving = false;
    }
  }
}
