import Component from "@glimmer/component";
import { tracked } from "@glimmer/tracking";
import { fn, hash } from "@ember/helper";
import { action } from "@ember/object";
import didInsert from "@ember/render-modifiers/modifiers/did-insert";
import { service } from "@ember/service";
import { extractError } from "discourse/lib/ajax-error";
import getURL from "discourse/lib/get-url";
import {
  grantableBadgeOptions,
  grantableBadges,
  isBadgeGrantable,
} from "discourse/lib/grant-badge-utils";
import { autoTrackedArray } from "discourse/lib/tracked-tools";
import Badge from "discourse/models/badge";
import UserBadge from "discourse/models/user-badge";
import ComboBox from "discourse/select-kit/components/combo-box";
import DButton from "discourse/ui-kit/d-button";
import DConditionalLoadingSpinner from "discourse/ui-kit/d-conditional-loading-spinner";
import DModal from "discourse/ui-kit/d-modal";
import DSelectBadge from "discourse/ui-kit/select/recipes/badges/d-select-badge";
import { i18n } from "discourse-i18n";

export default class GrantBadgeModal extends Component {
  @service siteSettings;

  @tracked loading = true;
  @tracked saving = false;

  /** @type {number | null} */
  @tracked selectedBadgeId = null;

  /** @type {string | null} */
  @tracked flash = null;

  /** @type {"success" | "error" | null} */
  @tracked flashType = null;
  @tracked allBadges = [];
  @tracked availableBadges = [];
  @autoTrackedArray userBadges = [];

  get noAvailableBadges() {
    return !this.availableBadges.length;
  }

  get badgeOptions() {
    return grantableBadgeOptions(this.availableBadges);
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
      this.userBadges.push(newBadge);
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

  #updateAvailableBadges() {
    this.availableBadges = grantableBadges(this.allBadges, this.userBadges);
  }

  <template>
    <DModal
      class="grant-badge-modal"
      @bodyClass="grant-badge"
      @closeModal={{@closeModal}}
      @flash={{this.flash}}
      @flashType={{this.flashType}}
      @title={{i18n "admin.badges.grant_badge"}}
      {{didInsert this.loadBadges}}
    >
      <:body>
        <DConditionalLoadingSpinner @condition={{this.loading}}>
          {{#if this.noAvailableBadges}}
            <p>{{i18n "admin.badges.no_badges"}}</p>
          {{else}}
            <p>
              {{! TODO (select-kit-replacement-cleanup): Remove the legacy branch after rollout. }}
              {{#if this.siteSettings.enable_new_select_controls}}
                <DSelectBadge
                  @identifier="grant-badge"
                  @noneOption={{true}}
                  @onChange={{fn (mut this.selectedBadgeId)}}
                  @options={{this.availableBadges}}
                  @texts={{hash
                    ariaLabel=(i18n "admin.badges.badge")
                    noneLabel=(i18n "badges.none")
                  }}
                  @value={{this.selectedBadgeId}}
                />
              {{else}}
                <ComboBox
                  @content={{this.badgeOptions}}
                  @onChange={{fn (mut this.selectedBadgeId)}}
                  @options={{hash filterable=true none="badges.none"}}
                  @value={{this.selectedBadgeId}}
                />
              {{/if}}
            </p>
          {{/if}}
        </DConditionalLoadingSpinner>
      </:body>
      <:footer>
        <DButton
          class="btn-primary"
          @action={{this.performGrantBadge}}
          @disabled={{this.buttonDisabled}}
          @label="admin.badges.grant"
        />
      </:footer>
    </DModal>
  </template>
}
