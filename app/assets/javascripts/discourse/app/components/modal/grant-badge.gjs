import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import ConditionalLoadingSpinner from "discourse/components/conditional-loading-spinner";
import DButton from "discourse/components/d-button";
import DModal from "discourse/components/d-modal";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import {
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import { i18n } from "discourse-i18n";
import ComboBox from "select-kit/components/combo-box";

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

  <template>
    <DModal
      @bodyClass="grant-badge"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @title={{i18n "admin.badges.grant_badge"}}
      class="grant-badge-modal"
      {{didInsert this.loadBadges}}
    >
      <:body>
        <ConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.noAvailableBadges}}
            <p>{{i18n "admin.badges.no_badges"}}</p>
          {{else}}
            <p>
              <ComboBox
                @value={{this.selectedBadgeId}}
                @content={{this.availableBadges}}
                @onChange={{fn (mut this.selectedBadgeId)}}
                @options={{hash filterable=true none="badges.none"}}
              />
            </p>
          {{/if}}
        </ConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          @disabled={{this.buttonDisabled}}
          @action={{this.performGrantBadge}}
          @label="admin.badges.grant"
          class="btn-primary"
        />
      </:footer>
    </DModal>
  </template>
}
